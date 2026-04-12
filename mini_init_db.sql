-- =========================================================================
-- 项目：外卖达人奖励系统
-- 用途：minidb 全新初始化部署 (mini_init_db.sql)
-- 版本：v6.0.0
-- 说明：基于 init.sql 改造，兼容无 pg_cron 环境
-- =========================================================================

-- -------------------------------------------------------------------------
-- 0. 初始化会话安全设置
-- -------------------------------------------------------------------------
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- -------------------------------------------------------------------------
-- 1. 创建 public schema
-- -------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS public;
COMMENT ON SCHEMA public IS 'standard public schema';

-- -------------------------------------------------------------------------
-- 2. 触发器函数：自动更新 last_used_at
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_last_used_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
   NEW.last_used_at = now();
   RETURN NEW;
END;
$$;

-- -------------------------------------------------------------------------
-- 3. 触发器函数：自动更新 updated_at
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$;

-- -------------------------------------------------------------------------
-- 4. 建表：profiles
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    device_id       TEXT        NOT NULL,
    last_active_at  TIMESTAMPTZ          DEFAULT now(),
    created_at      TIMESTAMPTZ          DEFAULT now(),
    CONSTRAINT profiles_pkey            PRIMARY KEY (id),
    CONSTRAINT profiles_device_id_key   UNIQUE (device_id)
);
COMMENT ON TABLE public.profiles IS '用户画像主表';

-- -------------------------------------------------------------------------
-- 5. 建表：profile_phones
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_phones (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    device_id       TEXT        NOT NULL,
    phone_number    TEXT        NOT NULL,
    is_primary      BOOLEAN              DEFAULT false,
    created_at      TIMESTAMPTZ          DEFAULT now(),
    last_used_at    TIMESTAMPTZ          DEFAULT now(),
    CONSTRAINT profile_phones_pkey                          PRIMARY KEY (id),
    CONSTRAINT profile_phones_device_id_phone_number_key    UNIQUE (device_id, phone_number),
    CONSTRAINT profile_phones_phone_number_check            CHECK (phone_number ~ '^1[3-9]\d{9}$'),
    CONSTRAINT profile_phones_device_id_fkey                FOREIGN KEY (device_id)
        REFERENCES public.profiles(device_id) ON DELETE CASCADE
);
COMMENT ON TABLE public.profile_phones IS '风控：设备关联手机号明细表';

-- -------------------------------------------------------------------------
-- 6. 建表：affiliate_orders
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.affiliate_orders (
    id               UUID        NOT NULL DEFAULT gen_random_uuid(),
    affiliate_source TEXT        NOT NULL,
    platform_type    INT         NOT NULL DEFAULT 0,
    order_id         TEXT        NOT NULL,
    device_id        TEXT        NOT NULL,
    status           TEXT        NOT NULL DEFAULT 'pending',
    settled_at       TIMESTAMPTZ,
    created_at       TIMESTAMPTZ          DEFAULT now(),
    CONSTRAINT affiliate_orders_pkey              PRIMARY KEY (id),
    CONSTRAINT affiliate_orders_source_order_key  UNIQUE (affiliate_source, order_id),
    CONSTRAINT affiliate_orders_source_check      CHECK (affiliate_source = ANY (ARRAY['jtk'::text, 'tb'::text])),
    CONSTRAINT affiliate_orders_status_check      CHECK (status = ANY (ARRAY['pending'::text, 'settled'::text, 'invalid'::text])),
    CONSTRAINT affiliate_orders_device_id_fkey    FOREIGN KEY (device_id)
        REFERENCES public.profiles(device_id) ON DELETE CASCADE
);
COMMENT ON TABLE public.affiliate_orders IS '多联盟归一化结算订单表';

-- -------------------------------------------------------------------------
-- 7. 建表：check_ins
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.check_ins (
    id          UUID    NOT NULL DEFAULT gen_random_uuid(),
    device_id   TEXT    NOT NULL,
    check_date  DATE    NOT NULL,
    created_at  TIMESTAMPTZ      DEFAULT now(),
    CONSTRAINT check_ins_pkey                       PRIMARY KEY (id),
    CONSTRAINT check_ins_device_id_check_date_key   UNIQUE (device_id, check_date),
    CONSTRAINT check_ins_device_id_fkey             FOREIGN KEY (device_id)
        REFERENCES public.profiles(device_id) ON DELETE CASCADE
);
COMMENT ON TABLE public.check_ins IS '用户每日红包打卡记录表';

-- -------------------------------------------------------------------------
-- 8. 建表：reward_claims
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reward_claims (
    id              UUID    NOT NULL DEFAULT gen_random_uuid(),
    device_id       TEXT    NOT NULL,
    claim_month     TEXT    NOT NULL,
    phone_number    TEXT    NOT NULL,
    platform        TEXT    NOT NULL,
    status          TEXT             DEFAULT 'processing',
    created_at      TIMESTAMPTZ      DEFAULT now(),
    updated_at      TIMESTAMPTZ      DEFAULT now(),
    CONSTRAINT reward_claims_pkey                           PRIMARY KEY (id),
    CONSTRAINT reward_claims_device_id_claim_month_key      UNIQUE (device_id, claim_month),
    CONSTRAINT reward_claims_phone_number_claim_month_key   UNIQUE (phone_number, claim_month),
    CONSTRAINT reward_claims_claim_month_check              CHECK (claim_month ~ '^\d{4}-\d{2}$'),
    CONSTRAINT reward_claims_phone_number_check             CHECK (phone_number ~ '^1[3-9]\d{9}$'),
    CONSTRAINT reward_claims_platform_check                 CHECK (platform = ANY (ARRAY['meituan'::text, 'taobao'::text])),
    CONSTRAINT reward_claims_status_check                   CHECK (status = ANY (ARRAY['processing'::text, 'success'::text, 'failed'::text, 'rejected'::text])),
    CONSTRAINT reward_claims_device_id_fkey                 FOREIGN KEY (device_id)
        REFERENCES public.profiles(device_id) ON DELETE CASCADE
);
COMMENT ON TABLE public.reward_claims IS '外卖奖励兑换申请与发货表';

-- -------------------------------------------------------------------------
-- 9. 性能索引
-- -------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_check_ins_date           ON public.check_ins        USING btree (check_date);
CREATE INDEX IF NOT EXISTS idx_check_ins_device_id      ON public.check_ins        USING btree (device_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_orders_device  ON public.affiliate_orders USING btree (device_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_orders_status  ON public.affiliate_orders USING btree (status);
CREATE INDEX IF NOT EXISTS idx_affiliate_orders_created ON public.affiliate_orders USING btree (created_at);
CREATE INDEX IF NOT EXISTS idx_profile_phones_device_id ON public.profile_phones   USING btree (device_id);
CREATE INDEX IF NOT EXISTS idx_profile_phones_phone     ON public.profile_phones   USING btree (phone_number);
CREATE INDEX IF NOT EXISTS idx_reward_claims_created_at ON public.reward_claims    USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reward_claims_device_id  ON public.reward_claims    USING btree (device_id);
CREATE INDEX IF NOT EXISTS idx_reward_claims_phone      ON public.reward_claims    USING btree (phone_number);

-- -------------------------------------------------------------------------
-- 10. 触发器绑定
-- -------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_update_profile_phones_last_used_at ON public.profile_phones;
CREATE TRIGGER trigger_update_profile_phones_last_used_at
    BEFORE UPDATE ON public.profile_phones
    FOR EACH ROW EXECUTE FUNCTION public.update_last_used_at_column();

DROP TRIGGER IF EXISTS trigger_update_reward_claims_updated_at ON public.reward_claims;
CREATE TRIGGER trigger_update_reward_claims_updated_at
    BEFORE UPDATE ON public.reward_claims
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- -------------------------------------------------------------------------
-- 11. 行级安全策略（RLS）开启
-- -------------------------------------------------------------------------
ALTER TABLE public.check_ins        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_phones   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_claims    ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- 12. 自动清理定时任务
--     Supabase 环境：执行 pg_cron 任务
--     minidb 环境：跳过（未安装 pg_cron）
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-old-checkins';
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-old-orders';
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-zombie-profiles';

    PERFORM cron.schedule(
      'cleanup-old-checkins', '0 18 * * *',
      $cron$ DELETE FROM public.check_ins WHERE check_date < current_date - interval '60 days'; $cron$
    );
    PERFORM cron.schedule(
      'cleanup-old-orders', '15 18 * * *',
      $cron$ DELETE FROM public.affiliate_orders WHERE created_at < now() - interval '90 days'; $cron$
    );
    PERFORM cron.schedule(
      'cleanup-zombie-profiles', '30 18 * * *',
      $cron$ DELETE FROM public.profiles WHERE last_active_at < now() - interval '180 days'; $cron$
    );
    RAISE NOTICE 'pg_cron 定时任务已注册';
  ELSE
    RAISE NOTICE 'pg_cron 未安装，跳过定时任务（minidb 环境）';
  END IF;
END
$$;

-- =========================================================================
-- 初始化完成
-- 结构：5 张表 / 2 个触发器函数 / 2 个触发器 / 10 个索引 / 5 张表 RLS 已开启
-- 定时任务：pg_cron 存在时自动注册，否则跳过
-- =========================================================================