FROM postgres:15-alpine
COPY entrypoint-replica.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint-replica.sh
ENTRYPOINT ["entrypoint-replica.sh"]