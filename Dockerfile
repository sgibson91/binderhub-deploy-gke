FROM kiwigrid/gcloud-kubectl-helm

ADD . /app
RUN find /app -type f -name '*.sh' -exec chmod +x {} \;

WORKDIR /app

CMD ["/app/deploy.sh"]
