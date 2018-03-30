#!/usr/bin/env sh

TRY_LOOP="20"


# Não checa nada se estivermos em ambiente de teste, visto que, POR ENQUANTO,
# estamos usando sqlite para testes.
export DB_HOST="postgres"
export DB_PORT="5432"

# Install custom python package if requirements.txt is present
if [ -e "/radar/radar_parlamentar/requirements.txt" ]; then
    pip install -r /radar/radar_parlamentar/requirements.txt
fi

wait_for_port() {
  local name="$1" host="$2" port="$3"
  local j=0
  while ! nc -z "$host" "$port" >/dev/null 2>&1 < /dev/null; do
    j=$((j+1))
    if [ $j -ge $TRY_LOOP ]; then
      echo >&2 "$(date) - $host:$port still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for $name... $j/$TRY_LOOP"
    sleep 5
  done
}

case "$1" in
  deploy)
    wait_for_port "Postgres" "$DB_HOST" "$DB_PORT"
    sleep 10
    python manage.py migrate
    python manage.py collectstatic --noinput
    uwsgi --ini /radar/deploy/radar_uwsgi.ini
    break
    ;;
  update)
    wait_for_port "Postgres" "$DB_HOST" "$DB_PORT"
    sleep 10
    python manage.py migrate
    python manage.py collectstatic --noinput
    break
    ;;
  test)
    export RADAR_TEST='True'
    python manage.py migrate
    python manage.py collectstatic --noinput
    python manage.py test
    rm -f /radar/radar_parlamentar/radar_parlamentar.db
    # The previous line is made for tests run on sqlite.
    break
    ;;
  *)
    # The command is something like bash, not an airflow subcommand. Just run it in the right environment.
    uwsgi --ini /radar/deploy/radar_uwsgi.ini
    break
    ;;
esac
