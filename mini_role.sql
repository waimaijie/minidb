-- =========================================================================
-- 兼容 Supabase 内置角色
-- =========================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'web_anon') THEN
    CREATE ROLE web_anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator WITH LOGIN PASSWORD 'dYns0Z_dojuvm50' NOINHERIT;
  END IF;
END
$$;

-- authenticator 可切换到所有角色
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;
GRANT web_anon TO authenticator;

-- =========================================================================
-- 基础 Schema 权限
-- =========================================================================
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role, web_anon, authenticator;

-- 现有对象权限
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated, web_anon;

GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, web_anon;

GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO postgres, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, web_anon;

-- 默认权限自动继承
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT ALL ON TABLES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated, web_anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT ALL ON SEQUENCES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated, web_anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT ALL ON FUNCTIONS TO postgres, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, web_anon;

-- =========================================================================
-- 兼容完成
-- =========================================================================