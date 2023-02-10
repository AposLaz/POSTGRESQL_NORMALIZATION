FROM postgres

WORKDIR /csv/movies_data/
COPY movies_data/ /csv/movies_data/
