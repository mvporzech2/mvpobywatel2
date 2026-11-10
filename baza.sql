-- =============================================
-- MVP Obywatel - Supabase Database Schema
-- Wgraj ten plik w Supabase SQL Editor
-- =============================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tabela kont użytkowników
CREATE TABLE accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    password TEXT NOT NULL,
    name TEXT,
    surname TEXT,
    sex TEXT,
    birthday TEXT,
    pesel TEXT,
    mdow_series TEXT,
    issue_date TEXT,
    expiry_date TEXT,
    father_name TEXT,
    mother_name TEXT,
    nationality TEXT,
    birth_place TEXT,
    birth_country TEXT,
    adress1 TEXT,
    adress2 TEXT,
    city TEXT,
    home_date TEXT,
    family_name TEXT,
    father_family_name TEXT,
    mother_family_name TEXT,
    image TEXT,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Każde konto musi mieć inne hasło.
CREATE UNIQUE INDEX IF NOT EXISTS accounts_password_unique
    ON public.accounts (password);

-- Jednorazowe klucze licencyjne.
-- Klucze są zużywane przez funkcję consume_license_key, a nie przez bezpośredni
-- odczyt z przeglądarki, dzięki czemu klient nie może pobrać całej tabeli.
CREATE TABLE keys (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    license_key TEXT NOT NULL UNIQUE,
    used_at TIMESTAMPTZ,
    used_by UUID REFERENCES accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE keys ENABLE ROW LEVEL SECURITY;

-- Atomowe zużycie klucza: przy równoczesnych żądaniach tylko jedno UPDATE
-- spełni warunek used_at IS NULL.
DROP FUNCTION IF EXISTS public.consume_license_key(TEXT, UUID);

CREATE OR REPLACE FUNCTION consume_license_key(p_key TEXT, p_account_id UUID DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    normalized_key TEXT;
BEGIN
    normalized_key := upper(regexp_replace(trim(p_key), '\s+', '', 'g'));

    UPDATE public.keys
    SET used_at = now(),
        used_by = p_account_id
    WHERE license_key = normalized_key
      AND used_at IS NULL;

    IF FOUND THEN
        RETURN 'consumed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.keys
        WHERE license_key = normalized_key
    ) THEN
        RETURN 'used';
    END IF;

    RETURN 'invalid';
END;
$$;

GRANT EXECUTE ON FUNCTION consume_license_key(TEXT, UUID) TO anon;

-- Atomowe utworzenie konta z kluczem licencyjnym.
-- Przy zajętym haśle klucz jest zwalniany i może użyć go inna próba.
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

    UPDATE public.keys
    SET used_at = now(),
        used_by = account_id
    WHERE license_key = normalized_key
      AND used_at IS NULL;

    IF NOT FOUND THEN
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
        RETURN 'created';
    EXCEPTION
        WHEN unique_violation THEN
            UPDATE public.keys
            SET used_at = NULL,
                used_by = NULL
            WHERE license_key = normalized_key
              AND used_by = account_id;

            IF EXISTS (
                SELECT 1
                FROM public.accounts
                WHERE password = p_account->>'password'
            ) THEN
                RETURN 'password_used';
            END IF;

            RAISE;
    END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_account_with_license(JSONB, TEXT) TO anon;

-- Generator uruchamiany ręcznie w Supabase SQL Editorze.
-- Korzysta z gen_random_uuid(), dostępnego w Supabase.
-- Zwraca klucz w formacie MVP-XXXXXXXX-XXXXXXXX-XXXXXXXX.
CREATE OR REPLACE FUNCTION generate_license_key()
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
            -- W praktyce skrajnie rzadkie; spróbuj wygenerować ponownie.
        END;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION generate_license_key() FROM PUBLIC, anon, authenticated;

-- Włącz Row Level Security
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

-- Pozwól anonowemu klientowi wstawiać rekordy (gen.html tworzy konta)
CREATE POLICY "anon_insert" ON accounts
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Pozwól anonowemu klientowi odczytywać rekordy (id.html sprawdza hasło)
CREATE POLICY "anon_select" ON accounts
    FOR SELECT
    TO anon
    USING (true);

-- Pozwól anonowemu klientowi aktualizować rekordy (aktualizacja wersji)
CREATE POLICY "anon_update" ON accounts
    FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);
