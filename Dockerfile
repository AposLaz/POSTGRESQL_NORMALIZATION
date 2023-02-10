FROM postgres

COPY ./movies_data/movies.csv .
USER root
RUN chmod -R 777 .