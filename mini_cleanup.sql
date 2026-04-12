-- =========================================================================
-- 项目：外卖达人奖励系统
-- 用途：minidb 手动清理脚本 (mini_cleanup.sql)
-- 说明：替代 pg_cron 定时任务，手动按需执行
-- =========================================================================

-- 清理 60 天前打卡记录
DELETE FROM public.check_ins
WHERE check_date < current_date - interval '60 days';

-- 清理 90 天前订单记录
DELETE FROM public.affiliate_orders
WHERE created_at < now() - interval '90 days';

-- 清理 180 天未活跃僵尸用户（级联删除所有关联数据）
DELETE FROM public.profiles
WHERE last_active_at < now() - interval '180 days';

-- =========================================================================
-- 清理完成
-- =========================================================================