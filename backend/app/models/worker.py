"""Worker (delivery partner) ORM model.

Represents a gig economy delivery worker registered on the GigShield platform.
Stores profile, location, platform affiliation, and income data used by the
pricing engine for risk assessment and premium calculation.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Worker(Base):
    """Gig delivery worker — the primary insured entity."""

    __tablename__ = "workers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    phone: Mapped[str] = mapped_column(String(15), unique=True, nullable=False, index=True)
    city: Mapped[str] = mapped_column(String(60), nullable=False)
    pincode: Mapped[str] = mapped_column(String(10), nullable=False)
    platform: Mapped[str] = mapped_column(String(20), nullable=False)  # zomato / swiggy
    avg_weekly_income_inr: Mapped[float] = mapped_column(Float, nullable=False)
    vehicle_type: Mapped[str] = mapped_column(String(30), nullable=False)  # bike / scooter / cycle
    hashed_otp: Mapped[str | None] = mapped_column(String(256), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    policies = relationship("Policy", back_populates="worker", lazy="noload")
    claims = relationship("Claim", back_populates="worker", lazy="noload")
    payouts = relationship("Payout", back_populates="worker", lazy="noload")
