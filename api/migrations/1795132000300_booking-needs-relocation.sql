-- Up Migration

ALTER TABLE bookings
  ADD COLUMN needs_relocation boolean NOT NULL DEFAULT false;

-- Down Migration

ALTER TABLE bookings
  DROP COLUMN needs_relocation;
