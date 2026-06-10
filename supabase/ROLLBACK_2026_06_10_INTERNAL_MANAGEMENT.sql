-- ============================================================================
-- Rollback helpers for 2026-06-10 internal management changes
-- IMPORTANT:
--   Do NOT run this file blindly.
--   Run only the section you need.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Rollback QA only (safe-ish)
-- This only disables the /admin/qa server check.
-- ----------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS public.qa_system_check(UUID);

-- ----------------------------------------------------------------------------
-- 2) Rollback photography RPCs only
-- This will break /admin/photography-management and /photographer/tasks actions.
-- It does NOT delete the photography_tasks table.
-- ----------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS public.create_photography_task_internal(UUID, UUID, UUID, TEXT, TIMESTAMPTZ);
-- DROP FUNCTION IF EXISTS public.submit_photography_task_internal(UUID, UUID, JSONB, TEXT);
-- DROP FUNCTION IF EXISTS public.update_photography_task_status_internal(UUID, UUID, INT, TEXT);
-- DROP FUNCTION IF EXISTS public.attach_photography_media_to_offer_internal(UUID, UUID);

-- ----------------------------------------------------------------------------
-- 3) Rollback photography table (DANGEROUS: deletes all photography tasks)
-- Backup first:
--   CREATE TABLE photography_tasks_backup AS SELECT * FROM photography_tasks;
-- ----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS public.photography_tasks CASCADE;

-- ----------------------------------------------------------------------------
-- 4) Rollback internal permissions RPCs
-- This will break /admin/permissions.
-- ----------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS public.admin_update_user_permissions(UUID, JSONB);
-- DROP FUNCTION IF EXISTS public.admin_update_user_permissions_by_admin(UUID, UUID, JSONB);

-- ----------------------------------------------------------------------------
-- 5) Rollback role/status RPCs
-- This will break user role/status updates from admin screens.
-- ----------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS public.admin_update_user_role(UUID, UUID, INT);
-- DROP FUNCTION IF EXISTS public.admin_set_user_status(UUID, UUID, INT, TEXT);

-- ----------------------------------------------------------------------------
-- 6) Rollback offer creation RPC
-- This will break current OfferProvider.addOffer implementation.
-- ----------------------------------------------------------------------------
-- DROP FUNCTION IF EXISTS public.create_offer_internal(UUID, JSONB);

-- ----------------------------------------------------------------------------
-- 7) Rollback phone uniqueness hardening
-- WARNING: this can allow duplicated accounts again.
-- ----------------------------------------------------------------------------
-- DROP INDEX IF EXISTS public.ux_users_normalized_phone_active;
-- DROP FUNCTION IF EXISTS public.normalize_sy_phone(TEXT);

-- ----------------------------------------------------------------------------
-- 8) Rollback users.perm column (DANGEROUS: loses custom permissions)
-- Backup first:
--   CREATE TABLE users_permissions_backup AS SELECT id, perm FROM users;
-- ----------------------------------------------------------------------------
-- ALTER TABLE public.users DROP COLUMN IF EXISTS perm;

-- ----------------------------------------------------------------------------
-- 9) Restore legacy create_user_from_phone/upsert_user_after_otp behavior
-- Not recommended. Prefer fixing specific issues instead.
-- ----------------------------------------------------------------------------
-- See git history before 2026-06-10 if a legacy restore is ever required.
