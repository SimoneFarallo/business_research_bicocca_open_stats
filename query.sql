--- Query1 : Distribuzione del numero degli studenti iscritti nei vari appelli, suddivisa per anni e per corso di laurea
SELECT a.appcod, c.cdscod,c.cds, count (s.studente) AS num_stud, strftime('%Y',a.dtappello) as year, a.dtappello
FROM studenti AS s JOIN iscrizioni AS i JOIN appelli_1 AS a JOIN cds AS c
ON s.studente=i.studente AND i.appcod= a.appcod AND a.cdscod = c.cdscod
GROUP BY c.cdscod, year,a.appcod
ORDER BY year asc

---Denormalizzata:

SELECT cdscod, cds, count (studente) AS num_stud, strftime('%Y', dtappello) AS year,dtappello
FROM bos_denormalizzato_1
GROUP BY cdscod,year, dtappello, ad, docente
ORDER BY year ASC

--- Query 2: Individuazione della Top-10 degli esami più difficili suddivisi per corso di studi. • Per esame più difficile si intende l’esame che presenta il tasso di superamento complessivo maggiore, considerando tutti gli appelli dell’Anno Accademico. Tasso di superamento è inteso come “numero di studenti che hanno superato l’appello” (Tab. Iscrizioni col. Superamento) su “numero di studenti che hanno partecipato all’appello” minore.
CREATE TABLE tasso_superamento 
AS SELECT cds, ad, appelli.adcod, sum(Iscrizione) as n_iscritti, sum(Superamento) as n_promossi, sum(Assenza) as Assenti
FROM appelli
JOIN iscrizioni on appelli.appcod=iscrizioni.appcod 
JOIN cds on appelli.cdscod=cds.cdscod
JOIN ad on appelli.adcod=ad.adcod
GROUP BY cds, ad, appelli.adcod

alter table tasso_superamento
     add tasso_superamento as (CAST (n_promossi as float) / (n_iscritti-Assenti))
	 
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY tasso_superamento) rn 
  FROM tasso_superamento  
)
WHERE rn <= 10
ORDER BY cds, tasso_superamento 

--- Denormalizzata:
SELECT CdS, AD, AdCod, sum(Iscrizione) as n_iscritti, sum(Superamento) as n_promossi , sum(Assenza) as Assenti
FROM bos_denormalizzato
GROUP BY CdS, AD, AdCod

alter table sup_denorm
     add tasso_superamento as (CAST (n_promossi as float) / (n_iscritti-Assenti))
	 
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY tasso_superamento) rn 
  FROM sup_denorm  
)
WHERE rn <= 10
ORDER BY cds, tasso_superamento 


--- Query 3: Individuazione dei corsi di laurea ad elevato tasso di commitment, ovvero appelli di esami diversi ma del medesimo corso di laurea che si sono svolti nello stesso giorno
SELECT c.cdscod,c.cds,a.dtappello, COUNT() AS commitment
FROM appelli_1 AS a JOIN cds AS c
ON a.cdscod= c.cdscod
GROUP BY c.cds, a.dtappello
ORDER BY commitment desc

--- Denormalizzata:

SELECT *, count() AS commitment
FROM(select distinct CdsCod,CdS, dtappello, Ad, Docente, TipoCorso, AdCod, AdSettCod
FROMbos_denormalizzato_1)
GROUP BY DtAppello, CdS
ORDER BY commitment desc

--- Query 4: Individuazione della Top-3 degli esami con media voti maggiore e minore rispettivamente, calcolati per ogni singolo corso di studi
CREATE TABLE new_table_2 AS
    SELECT cds, ad, appelli.adcod, cds.cdscod, AVG(Voto) AS media_voto
    FROM appelli
	JOIN iscrizioni ON  appelli.appcod=iscrizioni.appcod 
	JOIN cds ON appelli.cdscod=cds.cdscod 
	JOIN ad ON appelli.adcod=ad.adcod
    GROUP BY cds, cds.cdscod, ad, appelli.adcod
	
CREATE TABLE updated_table_2 AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto) rn 
  FROM new_table_2
  WHERE media_voto IS NOT NULL
)
WHERE rn <= 3  
ORDER BY cds, media_voto 

CREATE TABLE top_table_2 AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto DESC) rn 
  FROM new_table_2
  WHERE media_voto IS NOT 
NULL
)
WHERE rn <= 3  
ORDER BY cds, media_voto DESC

SELECT *
FROM updated_table_2
UNION
SELECT *
FROM top_table_2
ORDER BY cds, media_voto 

--- Denromalizzata:

CREATE TABLE table_2_denorm AS
    SELECT cds, ad, adcod, cdscod, AVG(Voto) AS media_voto
    FROM bos_denormalizzato
    GROUP BY cds, cdscod, ad, adcod
	
CREATE TABLE updated_table_2_denorm AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto) rn 
  FROM table_2_denorm
  WHERE media_voto IS NOT NULL
)
WHERE rn <= 3  
ORDER BY cds, media_voto 

CREATE TABLE top_table_2_denorm AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto DESC) rn 
  FROM table_2_denorm
  WHERE media_voto IS NOT NULL
)
WHERE rn <= 3  
ORDER BY cds, media_voto DESC

SELECT *
FROM updated_table_2_denorm
UNION
SELECT *
FROM top_table_2_denorm
ORDER BY cds, media_voto 


--- Query5 : Calcolare la distribuzione degli studenti “fast&furious” per corso di studi, ovvero studenti con il rapporto “votazione media riportata negli esami superati” su “periodo di attività” maggiore. Per periodo di attività si intende il numero di giorni trascorsi tra il primo appello sostenuto (non necessariamente superato) e l’ultimo.
SELECT *, media/diff AS score
FROM(select i.studente,c.cds, max(julianday(a.dtappello))- min((julianday(a.dtappello))) as diff,avg(i.voto) as media
from iscrizioni as i join studenti as s join appelli_1 as a join cds as c
on i.appcod=a.appcod and i.studente = s.studente and a.cdscod=c.cdscod
group by a.cdscod, i.studente)
ORDER BY diff ASC

--- Denormalizzata:
SELECT *, media/diff AS score
FROM(SELECT Studente,CdS, MAX(JULIANDAY(DtAppello))- MIN((JULIANDAY(DtAppello))) AS diff,AVG(Voto) AS media
FROM bos_denormalizzato
GROUP BY CdsCod, Studente)
ORDER BY diff ASC


--- Query 6: Individuazione della Top-3 degli esami “trial&error”, ovvero esami che richiedono il maggior numero di tentativi prima del superamento. Dato uno corso di studi, il rispettivo valore trial&error è dato dalla media del numero di tentativi (bocciature) di ogni studente per ogni appello del corso.

CREATE TABLE table_ex_6 AS
    SELECT cds, ad, appelli.adcod, cds.cdscod, SUM(Insufficienza) AS n_tentativi_studente
    FROM appelli
	JOIN iscrizioni ON  appelli.appcod=iscrizioni.appcod
	JOIN cds ON appelli.cdscod=cds.cdscod 
	JOIN ad ON appelli.adcod=ad.adcod
    GROUP BY cds, cds.cdscod, ad, appelli.adcod, studente
	
CREATE TABLE table_ex_6_2 AS
    SELECT  cds, ad, adcod, cdscod, AVG(n_tentativi_studente) AS trialerror
    FROM table_ex_6
    GROUP BY cds, cdscod, ad, adcod

SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY trialerror DESC) rn 
  FROM table_ex_6_2
  WHERE trialerror IS NOT NULL
)
WHERE rn <= 3  
ORDER BY cds, trialerror 

denormalizzato:

CREATE TABLE table_ex_6_denorm AS
    SELECT cds, ad, adcod, cdscod, sum(Insufficienza) AS n_tentativi_studente
    FROM bos_denormalizzato
    GROUP BY cds, cdscod, ad, adcod, studente

CREATE TABLE table_ex_6_2_denorm AS	
    SELECT  cds, ad, adcod, cdscod, avg(n_tentativi_studente) AS trialerror
    FROM table_ex_6_denorm
    GROUP BY cds, cdscod, ad, adcod
	
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY trialerror DESC) rn 
  FROM table_ex_6_2_denorm
  WHERE trialerror IS NOT NULL
)
WHERE rn <= 3  
ORDER BY cds, trialerror 


--- Query 7: Distribuzione dell’età dei top 10 studenti maschi e top 10 studentesse femmine per media voto, suddivisi per ogni corso di studi

CREATE TABLE query_7 AS
    SELECT cds, appelli.adcod, cds.cdscod, AVG(Voto) AS media_voto, studenti.genere, studenti.etaimm
    FROM appelli
	JOIN iscrizioni ON appelli.appcod=iscrizioni.appcod
          JOIN cds ON appelli.cdscod=cds.cdscod
	JOIN studenti ON studenti.studente=iscrizioni.studente
    GROUP BY cds, cds.cdscod, studenti.studente

UPDATE query_7 SET etaimm='25.5' WHERE etaimm='23-28'

CREATE TABLE query_7_M AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto DESC) rn 
  FROM query_7
  WHERE media_voto IS NOT NULL AND genere="M"
)
WHERE rn <= 10
ORDER BY cds, media_voto 

CREATE TABLE query_7_F AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto DESC) rn 
  FROM query_7
  WHERE media_voto IS NOT NULL AND genere="F"
)
WHERE rn <= 10
ORDER BY cds, media_voto DESC

SELECT *
FROM query_7_M
UNION
SELECT *
FROM query_7_F
ORDER BY cds, media_voto 

--- Denormalizzata:

CREATE TABLE query_7_denorm AS
    SELECT cds, adcod, cdscod, AVG(Voto) AS media_voto, StuGen, StuEtaImm
    FROM bos_denormalizzato
    GROUP BY cds, cdscod, studente
UPDATE query_7_denorm SET StuEtaImm='25.5' WHERE StuEtaImm='23-28'

CREATE TABLE query_7_M_denorm AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto DESC) rn 
  FROM query_7_denorm
  WHERE media_voto IS NOT NULL AND StuGen="M"
)
WHERE rn <= 10
ORDER BY cds, media_voto 

CREATE TABLE query_7_F_denorm AS
SELECT *
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY cds ORDER BY media_voto DESC) rn 
  FROM query_7_denorm
  WHERE media_voto is not NULL AND StuGen="F"
)
WHERE rn <= 10
ORDER BY cds, media_voto DESC

SELECT *
FROM query_7_M_denorm
UNION
SELECT *
FROM query_7_F_denorm
ORDER BY cds, media_voto



