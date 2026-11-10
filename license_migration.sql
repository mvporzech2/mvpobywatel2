-- Uruchom ten plik raz w Supabase SQL Editorze na istniejącej bazie.
-- Nie uruchamiaj ponownie całego baza.sql, jeśli tabela accounts już istnieje.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.keys (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    license_key TEXT NOT NULL UNIQUE,
    used_at TIMESTAMPTZ,
    used_by UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.keys ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX IF NOT EXISTS accounts_password_unique
    ON public.accounts (password);

CREATE OR REPLACE FUNCTION public.create_account_with_license(
    p_account JSONB,
    p_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    normalized_key TEXT;
    account_id UUID;
BEGIN
    normalized_key := upper(regexp_replace(trim(p_key), '\s+', '', 'g'));
    account_id := (p_account->>'id')::UUID;

    IF NOT EXISTS (
        SELECT 1
        FROM public.keys
        WHERE license_key = normalized_key
          AND used_at IS NULL
        FOR UPDATE
    ) THEN
        IF EXISTS (
            SELECT 1 FROM public.keys WHERE license_key = normalized_key
        ) THEN
            RETURN 'used';
        END IF;
        RETURN 'invalid';
    END IF;

    BEGIN
        INSERT INTO public.accounts
        SELECT (jsonb_populate_record(NULL::public.accounts, p_account)).*;

        UPDATE public.keys
        SET used_at = now(),
            used_by = account_id
        WHERE license_key = normalized_key
          AND used_at IS NULL;

        RETURN 'created';
    EXCEPTION
        WHEN unique_violation THEN
            UPDATE public.keys
            SET used_at = NULL,
                used_by = NULL
            WHERE license_key = normalized_key
              AND used_by = account_id;

            IF EXISTS (
                SELECT 1 FROM public.accounts
                WHERE password = p_account->>'password'
            ) THEN
                RETURN 'password_used';
            END IF;

            RAISE;
    END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_account_with_license(JSONB, TEXT) TO anon;

CREATE OR REPLACE FUNCTION public.generate_license_key()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_key TEXT;
BEGIN
    LOOP
        new_key := 'MVP-' ||
            upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)) || '-' ||
            upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8)) || '-' ||
            upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8));

        BEGIN
            INSERT INTO public.keys (license_key) VALUES (new_key);
            RETURN new_key;
        EXCEPTION WHEN unique_violation THEN
            NULL;
        END;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_license_key() FROM PUBLIC, anon, authenticated;

-- Sprawdzenie po migracji:
-- SELECT public.generate_license_key();

-- Odśwież cache funkcji RPC używany przez Supabase Data API.
NOTIFY pgrst, 'reload schema';
