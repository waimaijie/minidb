-- =========================================================================
-- [危险] 数据库重置与清理脚本 (teardown.sql)
-- 版本：v6.0.0 (适配多联盟统一架构)
-- 说明：幂等设计，可重复执行；执行后需重跑 init.sql 才能恢复服务
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1. 清理全部业务表（CASCADE 级联删除外键、索引、触发器）
--    ※ 依赖顺序：先删子表，最后删主表 profiles
-- -------------------------------------------------------------------------
DROP TABLE IF EXISTS public.reward_claims    CASCADE;
DROP TABLE IF EXISTS public.check_ins        CASCADE;
DROP TABLE IF EXISTS public.affiliate_orders CASCADE;
DROP TABLE IF EXISTS public.profile_phones   CASCADE;
DROP TABLE IF EXISTS public.profiles         CASCADE;

-- -------------------------------------------------------------------------
-- 2. 清理触发器函数
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_last_used_at_column CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column   CASCADE;

-- -------------------------------------------------------------------------
-- 3. 定时任务（pg_cron）
--    Supabase 环境执行，minidb 跳过（未安装 pg_cron 扩展）
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-old-checkins';
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-old-orders';
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-zombie-profiles';
    RAISE NOTICE 'pg_cron 任务已清理';
  ELSE
    RAISE NOTICE 'pg_cron 未安装，跳过定时任务清理（minidb 环境）';
  END IF;
END
$$;

-- =========================================================================
-- 清理完成，如需恢复请执行 init.sql
-- =========================================================================