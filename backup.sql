--
-- PostgreSQL database dump
--

\restrict Hb79hrQSzkz780sbsynLRwvZESYWqfnSQmWzDr4b86lzrOnkJbfvgcUjTaYjpMc

-- Dumped from database version 15.15 (Debian 15.15-1.pgdg13+1)
-- Dumped by pg_dump version 15.15 (Debian 15.15-1.pgdg13+1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: invoices; Type: TABLE; Schema: public; Owner: plateforme_user
--

CREATE TABLE public.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_number character varying(50) NOT NULL,
    user_id uuid NOT NULL,
    client_name character varying(200),
    client_email character varying(255),
    billing_address text,
    subtotal_ht numeric(10,4) NOT NULL,
    vat_rate numeric(5,2) DEFAULT 19.00,
    vat_amount numeric(10,4),
    total_ttc numeric(10,4) NOT NULL,
    status character varying(50) DEFAULT 'DRAFT'::character varying,
    issue_date date,
    due_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.invoices OWNER TO plateforme_user;

--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: plateforme_user
--

COPY public.invoices (id, invoice_number, user_id, client_name, client_email, billing_address, subtotal_ht, vat_rate, vat_amount, total_ttc, status, issue_date, due_date, created_at, updated_at) FROM stdin;
11111111-1111-1111-1111-111111111101	INV-2026-0001	11111111-1111-1111-1111-111111111111	Societe Atlas	contact@atlas.tn	Tunis, TN	1000.0000	19.00	190.0000	1190.0000	PAID	2026-01-10	2026-02-10	2026-01-28 14:36:57.438067	2026-01-28 14:36:57.438067
11111111-1111-1111-1111-111111111102	INV-2026-0002	11111111-1111-1111-1111-111111111111	Enterprise ABC	info@abc.tn	Sousse, TN	2500.0000	19.00	475.0000	2975.0000	SENT	2026-01-15	2026-02-15	2026-01-28 14:36:57.438067	2026-01-28 14:36:57.438067
11111111-1111-1111-1111-111111111103	INV-2026-0003	11111111-1111-1111-1111-111111111111	Startup XYZ	contact@xyz.tn	Sfax, TN	750.0000	19.00	142.5000	892.5000	DRAFT	2026-01-20	2026-02-20	2026-01-28 14:36:57.438067	2026-01-28 14:36:57.438067
\.


--
-- Name: invoices invoices_invoice_number_key; Type: CONSTRAINT; Schema: public; Owner: plateforme_user
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_invoice_number_key UNIQUE (invoice_number);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: plateforme_user
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict Hb79hrQSzkz780sbsynLRwvZESYWqfnSQmWzDr4b86lzrOnkJbfvgcUjTaYjpMc

