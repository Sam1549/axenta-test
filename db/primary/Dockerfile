FROM postgres:15-alpine
COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY pg_hba.conf /etc/postgresql/pg_hba.conf
COPY init-replication.sh /docker-entrypoint-initdb.d/
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]