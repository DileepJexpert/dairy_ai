"""Export current delivery PIN coverage to a private D1 import file.

Run against the authoritative PostgreSQL database and apply the resulting SQL
to staging D1 after migration 0004. Do not commit generated operational data.
"""

from __future__ import annotations

import argparse
import asyncio
from decimal import Decimal
from pathlib import Path

from sqlalchemy import select

from app.database import async_session_factory
from app.models.serviceable_pincode import ServiceablePincode


def _quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _fee_minor(value: Decimal | None) -> int:
    fee = value if value is not None else Decimal("0")
    minor = fee * 100
    if fee < 0 or minor != minor.to_integral_value():
        raise ValueError(f"Invalid delivery fee: {fee}")
    return int(minor)


async def export_coverage(output_sql: Path) -> int:
    async with async_session_factory() as session:
        rows = (await session.execute(
            select(ServiceablePincode).order_by(ServiceablePincode.pincode)
        )).scalars().all()

    statements = ["-- Private export of authoritative delivery coverage"]
    for row in rows:
        pincode = str(row.pincode)
        if len(pincode) != 6 or not pincode.isdigit():
            raise ValueError(f"Invalid pincode in master data: {pincode}")
        days_min = int(row.delivery_days_min)
        days_max = int(row.delivery_days_max)
        if days_min < 0 or days_max < days_min:
            raise ValueError(f"Invalid delivery day range for {pincode}")
        statements.append(
            "INSERT INTO serviceable_pincodes "
            "(pincode, city, state, is_serviceable, delivery_fee_minor, delivery_days_min, delivery_days_max) "
            f"VALUES ({_quote(pincode)}, {_quote(row.city)}, {_quote(row.state)}, "
            f"{1 if row.is_serviceable else 0}, {_fee_minor(row.delivery_fee)}, {days_min}, {days_max}) "
            "ON CONFLICT(pincode) DO UPDATE SET city=excluded.city, state=excluded.state, "
            "is_serviceable=excluded.is_serviceable, delivery_fee_minor=excluded.delivery_fee_minor, "
            "delivery_days_min=excluded.delivery_days_min, delivery_days_max=excluded.delivery_days_max;"
        )
    output_sql.parent.mkdir(parents=True, exist_ok=True)
    output_sql.write_text("\n".join(statements) + "\n", encoding="utf-8")
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-sql", type=Path, required=True)
    args = parser.parse_args()
    count = asyncio.run(export_coverage(args.output_sql))
    print(f"Exported {count} delivery PIN records to {args.output_sql}")


if __name__ == "__main__":
    main()
