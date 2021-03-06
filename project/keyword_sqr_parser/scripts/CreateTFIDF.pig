SQR = LOAD '/SQR' USING PigStorage(',') AS (campaign:chararray, adgroup:chararray, query:chararray, impressions:int, clicks:int);
SQR_Tuples = FILTER SQR BY NOT campaign == 'campaign';

DOCUMENTS_DEF = FOREACH SQR_Tuples GENERATE campaign, adgroup;
DOCUMENTS = DISTINCT DOCUMENTS_DEF;
DOCUMENTS_GROUP = GROUP DOCUMENTS ALL;
DOC_COUNT = FOREACH DOCUMENTS_GROUP GENERATE COUNT(DOCUMENTS) as documents;

TOKENS_TALL = FOREACH SQR_Tuples GENERATE campaign, adgroup, query, FLATTEN(TOKENIZE(query)) as token, impressions, clicks ;
DEDUPE_TOKENS_TALL = DISTINCT TOKENS_TALL;
TOKEN_GROUP = GROUP DEDUPE_TOKENS_TALL BY (token, adgroup, campaign);

TF = FOREACH TOKEN_GROUP GENERATE group, COUNT(DEDUPE_TOKENS_TALL) as tf, 
    SUM(DEDUPE_TOKENS_TALL.impressions) as impressions_gross,
    SUM(DEDUPE_TOKENS_TALL.clicks) as clicks_gross;

DOC_TEMP = FOREACH TF GENERATE group.token, group.adgroup, group.campaign;
DOC_GROUP = GROUP DOC_TEMP BY token;

DOC_FREQ = FOREACH DOC_GROUP GENERATE group as token, COUNT(DOC_TEMP) as df;

DOC_FREQ_COUNT = CROSS DOC_FREQ, DOC_COUNT;
DFC_UNPACK = FOREACH DOC_FREQ_COUNT GENERATE $0 as token, $1 as df, $2 as docs;

IDF = FOREACH DFC_UNPACK GENERATE token, df, docs, LOG10(docs / df) as idf;

TFIDF_TEMP = JOIN TF BY group.token, IDF BY token;

TFIDF = FOREACH TFIDF_TEMP GENERATE group.token, group.adgroup, group.campaign, impressions_gross, clicks_gross, tf * idf as tfidf;

rmf /TFIDF
STORE TFIDF INTO '/TFIDF' USING PigStorage(',');