--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.4
-- Dumped by pg_dump version 9.4.0
-- Started on 2015-07-29 10:47:59 CEST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 2090 (class 1262 OID 16384)
-- Name: fcore; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE fcore WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE fcore OWNER TO postgres;

\connect fcore

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 179 (class 3079 OID 11861)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2093 (class 0 OID 0)
-- Dependencies: 179
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 202 (class 1255 OID 16511)
-- Name: authors_set(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION authors_set() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN

		INSERT INTO authors (cid, fid, tid, mid, uid)
		VALUES (NEW.cid, NEW.fid, NEW.tid, NEW.id, lower(NEW.a));
		RETURN NEW;
	END;
$$;


ALTER FUNCTION public.authors_set() OWNER TO postgres;

--
-- TOC entry 201 (class 1255 OID 17067)
-- Name: base36_decode(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION base36_decode(base36 character varying) RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE
    AS $$
        DECLARE
			a char[];
			ret bigint;
			i int;
			val int;
			chars varchar;
		BEGIN
		chars := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
 
		FOR i IN REVERSE char_length(base36)..1 LOOP
			a := a || substring(upper(base36) FROM i FOR 1)::char;
		END LOOP;
		i := 0;
		ret := 0;
		WHILE i < (array_length(a,1)) LOOP		
			val := position(a[i+1] IN chars)-1;
			ret := ret + (val * (36 ^ i));
			i := i + 1;
		END LOOP;
 
		RETURN ret;
 
END;
$$;


ALTER FUNCTION public.base36_decode(base36 character varying) OWNER TO postgres;

--
-- TOC entry 192 (class 1255 OID 16434)
-- Name: base36_encode(bigint, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION base36_encode(digits bigint, min_width integer DEFAULT 0) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    chars char[]; 
    ret varchar; 
    val bigint; 
BEGIN
    chars := ARRAY['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z'];
    val := digits; 
    ret := ''; 
    IF val < 0 THEN 
        val := val * -1; 
    END IF; 
    WHILE val != 0 LOOP 
        ret := chars[(val % 36)+1] || ret; 
        val := val / 36; 
    END LOOP;

    IF min_width > 0 AND char_length(ret) < min_width THEN 
        ret := lpad(ret, min_width, '0'); 
    END IF;

    RETURN ret;
END;
$$;


ALTER FUNCTION public.base36_encode(digits bigint, min_width integer) OWNER TO postgres;

--
-- TOC entry 193 (class 1255 OID 16449)
-- Name: base36_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION base36_timestamp() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN base36_encode(CAST(extract(epoch from now() at time zone 'utc') * 1000 AS int8)); 
END;
$$;


ALTER FUNCTION public.base36_timestamp() OWNER TO postgres;

--
-- TOC entry 204 (class 1255 OID 16531)
-- Name: c_setcid(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION c_setcid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW.id := NEW.pid || '_' || get_unique_ts('0');
    RETURN NEW;
  END;
$$;


ALTER FUNCTION public.c_setcid() OWNER TO postgres;

--
-- TOC entry 198 (class 1255 OID 16480)
-- Name: f_decrthreadcounter(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION f_decrthreadcounter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE f SET
			tt = tt - 1,
			v = OLD.v
		WHERE id = OLD.fid;
		RETURN OLD;
    END;
$$;


ALTER FUNCTION public.f_decrthreadcounter() OWNER TO postgres;

--
-- TOC entry 197 (class 1255 OID 16432)
-- Name: f_incrthreadcounter(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION f_incrthreadcounter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE f SET
			tt = tt + 1,
			v = NEW.v
		WHERE id = NEW.fid;
		RETURN NEW;
    END;
$$;


ALTER FUNCTION public.f_incrthreadcounter() OWNER TO postgres;

--
-- TOC entry 194 (class 1255 OID 16503)
-- Name: f_touch(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION f_touch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

	BEGIN
		
		UPDATE f SET
			v = NEW.v
		WHERE id = NEW.fid;
		RETURN NEW;
    END;
$$;


ALTER FUNCTION public.f_touch() OWNER TO postgres;

--
-- TOC entry 203 (class 1255 OID 17070)
-- Name: get_unique_ts(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_unique_ts(ret character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF ret = '0' THEN
		ret := base36_timestamp();
	END IF;
	BEGIN
		INSERT INTO timekeeper (t) VALUES (ret);
		EXCEPTION WHEN unique_violation THEN
			ret = base36_encode(base36_decode(ret) + 1);
			RETURN get_unique_ts(ret);
	END;

    RETURN ret;
END;
$$;


ALTER FUNCTION public.get_unique_ts(ret character varying) OWNER TO postgres;

--
-- TOC entry 200 (class 1255 OID 16600)
-- Name: t_decrthreadcounter(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION t_decrthreadcounter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE t SET
			tm = tm - 1,
			v = base36_timestamp()
		WHERE fid = OLD.fid AND id = OLD.tid;
		RETURN OLD;
    END;
$$;


ALTER FUNCTION public.t_decrthreadcounter() OWNER TO postgres;

--
-- TOC entry 196 (class 1255 OID 16501)
-- Name: t_incrmsgcounter(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION t_incrmsgcounter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	issticky bit;
	mid char(9);

	BEGIN
		SELECT top INTO issticky FROM t WHERE id = NEW.tid;
		IF issticky THEN
			mid := lower(NEW.id);
		ELSE
			mid := NEW.id;
		END IF;
		UPDATE t SET
			tm = tm + 1,
			la = NEW.a,
			lm = mid,
			v = NEW.v
		WHERE id = NEW.tid;
		UPDATE f SET
			tm = tm + 1,
			v = NEW.v
		WHERE id = NEW.fid;
		RETURN NEW;
    END;
$$;


ALTER FUNCTION public.t_incrmsgcounter() OWNER TO postgres;

--
-- TOC entry 199 (class 1255 OID 16529)
-- Name: t_setlastdata(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION t_setlastdata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE
	lastauthor varchar(32);
	lastmessage char(9);

	BEGIN
		SELECT a, id INTO lastauthor, lastmessage
		FROM m 
		WHERE fid = OLD.fid AND tid = OLD.tid
		ORDER BY id DESC
		LIMIT 1;

		UPDATE t SET
		la = lastauthor,
		lm = lastmessage
		WHERE fid = OLD.fid AND id = OLD.tid;
		RETURN OLD;
    END;
$$;


ALTER FUNCTION public.t_setlastdata() OWNER TO postgres;

--
-- TOC entry 195 (class 1255 OID 16505)
-- Name: t_touch(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION t_touch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

	BEGIN
		
		UPDATE t SET
			v = NEW.v
		WHERE id = NEW.tid;
		RETURN NEW;
    END;
$$;


ALTER FUNCTION public.t_touch() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 175 (class 1259 OID 16418)
-- Name: authors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE authors (
    cid character varying(41) NOT NULL,
    uid character varying(32) NOT NULL,
    mid character(9) NOT NULL,
    fid character(9) NOT NULL,
    tid character(9) NOT NULL
);


ALTER TABLE authors OWNER TO postgres;

--
-- TOC entry 172 (class 1259 OID 16385)
-- Name: c; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE c (
    pid character varying(32) NOT NULL,
    v character(8) DEFAULT base36_timestamp() NOT NULL,
    p json NOT NULL,
    id character varying(41) DEFAULT NULL::character varying NOT NULL
);


ALTER TABLE c OWNER TO postgres;

--
-- TOC entry 173 (class 1259 OID 16394)
-- Name: f; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE f (
    id character(9) DEFAULT ('F'::text || (get_unique_ts('0'::character varying))::text) NOT NULL,
    cid character varying(41) NOT NULL,
    tpid character varying(32) NOT NULL,
    v character(8) DEFAULT base36_timestamp() NOT NULL,
    tm integer DEFAULT 0 NOT NULL,
    tt integer DEFAULT 0 NOT NULL,
    p json NOT NULL
);


ALTER TABLE f OWNER TO postgres;

--
-- TOC entry 178 (class 1259 OID 16467)
-- Name: m; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE m (
    id character(9) DEFAULT ('M'::text || (get_unique_ts('0'::character varying))::text) NOT NULL,
    v character(8) DEFAULT base36_timestamp() NOT NULL,
    tid character(9) NOT NULL,
    a character varying(32) NOT NULL,
    p json NOT NULL,
    fid character(9) NOT NULL,
    cid character varying(41) NOT NULL,
    la character varying(32)
);


ALTER TABLE m OWNER TO postgres;

--
-- TOC entry 176 (class 1259 OID 16423)
-- Name: t; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE t (
    id character(9) DEFAULT ('T'::text || (get_unique_ts('0'::character varying))::text) NOT NULL,
    fid character(9) NOT NULL,
    a character varying(32) NOT NULL,
    top bit(1) NOT NULL,
    v character(8) DEFAULT base36_timestamp() NOT NULL,
    tm integer DEFAULT 0 NOT NULL,
    p json NOT NULL,
    la character varying(32),
    lm character(9)
);


ALTER TABLE t OWNER TO postgres;

--
-- TOC entry 177 (class 1259 OID 16435)
-- Name: timekeeper; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE timekeeper (
    t character(8) NOT NULL
);


ALTER TABLE timekeeper OWNER TO postgres;

--
-- TOC entry 174 (class 1259 OID 16406)
-- Name: u; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE u (
    id character varying(32) NOT NULL,
    cid character varying(41) NOT NULL,
    c character(8) DEFAULT base36_timestamp() NOT NULL,
    v character(8) DEFAULT base36_timestamp() NOT NULL,
    p json NOT NULL,
    extid character varying(256)
);


ALTER TABLE u OWNER TO postgres;

--
-- TOC entry 1940 (class 2606 OID 16552)
-- Name: c_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY c
    ADD CONSTRAINT c_pkey PRIMARY KEY (id);


--
-- TOC entry 1943 (class 2606 OID 16403)
-- Name: f_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY f
    ADD CONSTRAINT f_pkey PRIMARY KEY (id);


--
-- TOC entry 1961 (class 2606 OID 16479)
-- Name: m_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY m
    ADD CONSTRAINT m_pkey PRIMARY KEY (fid, tid, id);


--
-- TOC entry 1956 (class 2606 OID 16526)
-- Name: t_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY t
    ADD CONSTRAINT t_pkey PRIMARY KEY (fid, id);


--
-- TOC entry 1958 (class 2606 OID 16446)
-- Name: timekeeper_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY timekeeper
    ADD CONSTRAINT timekeeper_pkey PRIMARY KEY (t);


--
-- TOC entry 1948 (class 2606 OID 17033)
-- Name: u_pk_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY u
    ADD CONSTRAINT u_pk_unique UNIQUE (id, cid);


--
-- TOC entry 1950 (class 2606 OID 16562)
-- Name: u_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY u
    ADD CONSTRAINT u_pkey PRIMARY KEY (cid, id);


--
-- TOC entry 1938 (class 1259 OID 16553)
-- Name: c_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX c_id_key ON c USING btree (id);


--
-- TOC entry 1951 (class 1259 OID 16568)
-- Name: cid_uid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cid_uid ON authors USING btree (cid, uid);


--
-- TOC entry 1944 (class 1259 OID 16404)
-- Name: idx_cid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_cid ON f USING btree (cid);


--
-- TOC entry 1946 (class 1259 OID 16417)
-- Name: idx_extid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX idx_extid ON u USING btree (extid, cid);


--
-- TOC entry 1941 (class 1259 OID 16546)
-- Name: idx_pid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_pid ON c USING btree (pid);


--
-- TOC entry 1945 (class 1259 OID 16405)
-- Name: idx_tpid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX idx_tpid ON f USING btree (tpid);


--
-- TOC entry 1959 (class 1259 OID 16513)
-- Name: m_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX m_id_key ON m USING btree (id);


--
-- TOC entry 1952 (class 1259 OID 16572)
-- Name: mid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX mid ON authors USING btree (mid);


--
-- TOC entry 1954 (class 1259 OID 16488)
-- Name: t_id_key; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNIQUE INDEX t_id_key ON t USING btree (id);


--
-- TOC entry 1953 (class 1259 OID 16571)
-- Name: tid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tid ON authors USING btree (tid);


--
-- TOC entry 1974 (class 2620 OID 16512)
-- Name: authors_set; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER authors_set AFTER INSERT ON m FOR EACH ROW EXECUTE PROCEDURE authors_set();


--
-- TOC entry 1968 (class 2620 OID 16549)
-- Name: c_setcid; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER c_setcid BEFORE INSERT ON c FOR EACH ROW EXECUTE PROCEDURE c_setcid();


--
-- TOC entry 1970 (class 2620 OID 16481)
-- Name: f_decrthreadcounter; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER f_decrthreadcounter AFTER DELETE ON t FOR EACH ROW EXECUTE PROCEDURE f_decrthreadcounter();


--
-- TOC entry 1969 (class 2620 OID 16433)
-- Name: f_incrthreadcounter; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER f_incrthreadcounter AFTER INSERT ON t FOR EACH ROW EXECUTE PROCEDURE f_incrthreadcounter();


--
-- TOC entry 1971 (class 2620 OID 16504)
-- Name: f_touch; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER f_touch AFTER UPDATE ON t FOR EACH ROW EXECUTE PROCEDURE f_touch();


--
-- TOC entry 1976 (class 2620 OID 16601)
-- Name: t_decrmsgcounter; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER t_decrmsgcounter AFTER DELETE ON m FOR EACH ROW EXECUTE PROCEDURE t_decrthreadcounter();


--
-- TOC entry 1972 (class 2620 OID 16502)
-- Name: t_incrmsgcounter; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER t_incrmsgcounter AFTER INSERT ON m FOR EACH ROW EXECUTE PROCEDURE t_incrmsgcounter();


--
-- TOC entry 1975 (class 2620 OID 16599)
-- Name: t_setlastdata; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER t_setlastdata AFTER DELETE ON m FOR EACH ROW EXECUTE PROCEDURE t_setlastdata();


--
-- TOC entry 1973 (class 2620 OID 16506)
-- Name: t_touch; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER t_touch AFTER UPDATE ON m FOR EACH ROW EXECUTE PROCEDURE t_touch();


--
-- TOC entry 1965 (class 2606 OID 17034)
-- Name: authors_u_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY authors
    ADD CONSTRAINT authors_u_fkey FOREIGN KEY (cid, uid) REFERENCES u(cid, id) ON DELETE CASCADE;


--
-- TOC entry 1963 (class 2606 OID 16563)
-- Name: c_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY u
    ADD CONSTRAINT c_id FOREIGN KEY (cid) REFERENCES c(id) ON DELETE CASCADE;


--
-- TOC entry 1962 (class 2606 OID 16607)
-- Name: fk_c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY f
    ADD CONSTRAINT fk_c FOREIGN KEY (cid) REFERENCES c(id) ON DELETE CASCADE;


--
-- TOC entry 1966 (class 2606 OID 16483)
-- Name: fk_f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY t
    ADD CONSTRAINT fk_f FOREIGN KEY (fid) REFERENCES f(id) ON DELETE CASCADE;


--
-- TOC entry 1967 (class 2606 OID 16489)
-- Name: fk_t; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY m
    ADD CONSTRAINT fk_t FOREIGN KEY (tid) REFERENCES t(id) ON DELETE CASCADE;


--
-- TOC entry 1964 (class 2606 OID 16520)
-- Name: m_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY authors
    ADD CONSTRAINT m_id FOREIGN KEY (mid) REFERENCES m(id) ON DELETE CASCADE;


--
-- TOC entry 2092 (class 0 OID 0)
-- Dependencies: 5
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2015-07-29 10:48:04 CEST

--
-- PostgreSQL database dump complete
--

