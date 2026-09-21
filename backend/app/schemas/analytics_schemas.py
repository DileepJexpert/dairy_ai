from pydantic import BaseModel, Field
from typing import Any


class VisitRegisterRequest(BaseModel):
    session_id: str = Field(..., description="Persistent client-side session identifier")
    referrer: str | None = None
    utm_source: str | None = None
    utm_medium: str | None = None
    utm_campaign: str | None = None
    utm_content: str | None = None
    landing_page: str = "/shop"
    device_type: str = "mobile"
    browser: str | None = None
    os: str | None = None
    city: str | None = None
    state: str | None = None
    country: str = "India"


class VisitRegisterResponse(BaseModel):
    session_id: str
    city: str | None = None
    state: str | None = None
    country: str = "India"
    message: str = "Visit recorded"


class ClickstreamEventCreate(BaseModel):
    session_id: str
    event_type: str
    page_url: str
    element_id: str | None = None
    element_text: str | None = None
    target_id: str | None = None
    metadata: dict[str, Any] | None = None


class BatchEventsRequest(BaseModel):
    events: list[ClickstreamEventCreate]


class CartItemAdminView(BaseModel):
    product_id: str
    title: str
    primary_image: str | None = None
    quantity: int
    unit_price: str
    line_total: str
    stock_available: int = 0


class AdminCartSummary(BaseModel):
    cart_id: str
    user_id: str
    user_phone: str
    user_role: str
    status: str
    is_abandoned: bool
    item_count: int
    subtotal: str
    created_at: str
    updated_at: str
    inactive_duration_minutes: int
    items: list[CartItemAdminView]


class CartRecoveryNudgeResponse(BaseModel):
    cart_id: str
    user_phone: str
    whatsapp_link: str
    sms_message: str
    coupon_code: str


class GeoMetric(BaseModel):
    name: str
    visitors_count: int
    percent: float


class ReferrerMetric(BaseModel):
    source: str
    type: str
    visitors_count: int
    percent: float


class TrafficSummaryResponse(BaseModel):
    total_visitors: int
    today_visitors: int
    live_visitors_30m: int
    total_page_views: int
    bounce_rate_percent: float
    avg_session_duration_seconds: int
    top_cities: list[GeoMetric]
    top_states: list[GeoMetric]
    top_referrers: list[ReferrerMetric]
    device_breakdown: dict[str, int]


class ClickstreamTimelineEvent(BaseModel):
    id: str
    session_id: str
    user_id: str | None = None
    user_phone: str | None = None
    event_type: str
    page_url: str
    element_id: str | None = None
    element_text: str | None = None
    target_id: str | None = None
    metadata: dict[str, Any] | None = None
    created_at: str


class AdminCartListResponse(BaseModel):
    success: bool = True
    data: list[AdminCartSummary]
    total: int
    message: str = "Carts retrieved successfully"


class ClickstreamTimelineResponse(BaseModel):
    success: bool = True
    data: list[ClickstreamTimelineEvent]
    total: int
    message: str = "Clickstream events retrieved successfully"


class SessionCartItemView(BaseModel):
    product_id: str
    title: str
    primary_image: str | None = None
    quantity: int
    unit_price: str
    line_total: str


class CustomerSessionJourneyView(BaseModel):
    session_id: str
    user_id: str | None = None
    customer_name: str | None = None
    customer_phone: str | None = None
    city: str = "Unknown"
    state: str = "Unknown"
    country: str = "India"
    ip_address: str | None = None
    device_type: str = "mobile"
    browser: str | None = None
    os: str | None = None
    referrer: str | None = None
    referrer_type: str = "direct"
    started_at: str
    last_seen_at: str
    duration_minutes: int = 1
    inactive_minutes: int = 0
    is_live: bool = False
    page_views_count: int = 1
    farthest_stage: str = "LANDED"  # LANDED, PRODUCT_VIEW, CART_ADDED, CHECKOUT_INITIATED, ADDRESS_ENTERED, PAYMENT_PENDING, ORDER_COMPLETED
    farthest_stage_label: str = "1. Landed on Store"
    stuck_status: str = "ACTIVE_BROWSING"  # ACTIVE_BROWSING, STUCK_PRODUCT, STUCK_CART, STUCK_CHECKOUT, STUCK_PAYMENT, CONVERTED, BOUNCED
    stuck_status_label: str = "Active Browsing"
    stuck_diagnosis: str = "Visitor currently browsing catalogue"
    last_page_url: str = "/shop"
    last_action_text: str = "Browsing Storefront"
    cart_id: str | None = None
    cart_item_count: int = 0
    cart_subtotal: str = "0.00"
    cart_items: list[SessionCartItemView] = Field(default_factory=list)
    journey_steps: list[dict[str, Any]] = Field(default_factory=list)


class FunnelStepSummary(BaseModel):
    stage_key: str
    stage_name: str
    visitor_count: int
    conversion_percent: float
    drop_off_count: int
    drop_off_percent: float


class CustomerSessionsResponse(BaseModel):
    total_visitors: int
    live_visitors_count: int
    stuck_visitors_count: int
    cart_abandoned_count: int
    checkout_stuck_count: int
    converted_count: int
    funnel_steps: list[FunnelStepSummary]
    sessions: list[CustomerSessionJourneyView]

