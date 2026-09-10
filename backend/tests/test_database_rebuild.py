import pytest
import os
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool
import scripts.rebuild_local_database as rebuild_module
from types import SimpleNamespace
from app.services import auth_service

from scripts.rebuild_local_database import validate_metadata, validate_target


@pytest.mark.parametrize('url,env,confirmation', [
    ('postgresql+asyncpg://u:p@localhost/example', 'production', 'example'),
    ('postgresql+asyncpg://u:p@remote/example', 'development', 'example'),
    ('postgresql+asyncpg://u:p@localhost/postgres', 'development', 'postgres'),
    ('postgresql+asyncpg://u:p@localhost/template1', 'test', 'template1'),
    ('postgresql+asyncpg://u:p@localhost/example', 'test', 'different'),
    ('postgresql+asyncpg://u:p@localhost/example', 'test', None),
    ('postgresql+asyncpg://u:p@localhost/example?host=remote', 'test', 'example'),
    ('sqlite+aiosqlite:///example', 'test', 'example'),
])
def test_rebuild_rejects_unsafe_targets(url, env, confirmation):
    with pytest.raises(ValueError):
        validate_target(url, env, confirmation, execute=True)


def test_dry_run_and_confirmed_local_target():
    url = 'postgresql+asyncpg://u:p@127.0.0.1/example'
    assert validate_target(url, 'development').database == 'example'
    assert validate_target(url, 'test', 'example', execute=True).database == 'example'


def test_complete_model_enum_names_do_not_conflict():
    validate_metadata()


@pytest.mark.asyncio
@pytest.mark.parametrize('environment,expected', [('development', '123456'), ('test', '123456'), ('production', '654321')])
async def test_demo_otp_shortcut_is_local_only(db_session, monkeypatch, environment, expected):
    monkeypatch.setattr(auth_service, 'get_settings', lambda: SimpleNamespace(APP_ENV=environment, JWT_SECRET='unit-test-secret'))
    monkeypatch.setattr(auth_service, 'generate_otp', lambda: '654321')
    assert await auth_service.send_otp(db_session, '9999900000') == expected


@pytest.mark.asyncio
@pytest.mark.skipif(not os.getenv('REBUILD_TEST_DATABASE_URL'), reason='Requires explicitly named disposable PostgreSQL test database')
async def test_postgres_repeat_rebuild_and_transaction_rollback(monkeypatch):
    url = os.environ['REBUILD_TEST_DATABASE_URL']
    target = validate_target(url, 'test')
    assert target.database.startswith('milterra_rebuild_verify_'), 'Only disposable rebuild verification databases allowed'
    await rebuild_module.rebuild(url, 'test', target.database, demo=True)
    # Reconnect after DDL; running backend pools must likewise be restarted.
    engine = create_async_engine(url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            assert await conn.scalar(text('SELECT count(*) FROM products')) == 4
            assert await conn.scalar(text('SELECT count(*) FROM commerce_product_classifications')) == 4
            await conn.execute(text('CREATE TABLE rebuild_sentinel(id integer)'))
        original = rebuild_module.seed_foundation
        async def fail_seed(*args):
            raise RuntimeError('intentional seed failure')
        monkeypatch.setattr(rebuild_module, 'seed_foundation', fail_seed)
        with pytest.raises(RuntimeError, match='intentional seed failure'):
            await rebuild_module.rebuild(url, 'test', target.database, demo=True)
        async with engine.connect() as conn:
            assert await conn.scalar(text("SELECT to_regclass('public.rebuild_sentinel') IS NOT NULL"))
            assert await conn.scalar(text('SELECT count(*) FROM products')) == 4
        monkeypatch.setattr(rebuild_module, 'seed_foundation', original)
        await rebuild_module.rebuild(url, 'test', target.database, demo=True)
        async with engine.connect() as conn:
            assert await conn.scalar(text("SELECT to_regclass('public.rebuild_sentinel') IS NULL"))
            assert await conn.scalar(text('SELECT count(*) FROM commerce_taxonomy_nodes')) == 7
            assert await conn.scalar(text('SELECT count(*) FROM products')) == 4
            # Shopping and farmer payment enums must coexist in PostgreSQL.
            assert await conn.scalar(text("SELECT 'paid'::commerce_payment_status::text")) == 'paid'
            assert await conn.scalar(text("SELECT 'processing'::paymentstatus::text")) == 'processing'
    finally:
        await engine.dispose()
