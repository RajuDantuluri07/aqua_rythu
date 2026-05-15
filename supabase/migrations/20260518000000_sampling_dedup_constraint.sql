-- Prevent duplicate sampling entries for the same pond on the same day.
-- The app already guards this client-side, but the DB constraint is the
-- final line of defence against network retries and concurrent submissions.
ALTER TABLE samplings
  ADD CONSTRAINT samplings_pond_doc_date_unique
  UNIQUE (pond_id, doc, (created_at::date));
