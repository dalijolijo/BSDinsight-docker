#!/bin/bash
set -u

# Downloading bootstrap file
cd /home/bitsend/bitcore-livenet/bin/mynode/data
if [ ! -d /home/bitsend/bitcore-livenet/bin/mynode/data/data/blocks ] && [ "$(curl -Is https://${WEB}/${BOOTSTRAP} | head -n 1 | tr -d '\r\n')" = "HTTP/1.1 200 OK" ] ; then \
        wget https://${WEB}/${BOOTSTRAP}; \
        tar -xvzf ${BOOTSTRAP}; \
        rm ${BOOTSTRAP}; \
fi

# Create script to downloading new bitsend.conf and replace the old one
echo "#!/bin/bash" > /usr/local/bin/new_config.sh
echo "echo \"Downloading new bitsend.conf and replace the old one. Please wait...\"" >> /usr/local/bin/new_config.sh
echo "mv /home/bitsend/bitcore-livenet/bin/mynode/data/bitsend.conf /home/bitsend/bitcore-livenet/bin/mynode/data/bitsend.conf.bak" >> /usr/local/bin/new_config.sh
echo "wget https://raw.githubusercontent.com/dalijolijo/BSDinsight-docker/master/bitsend.conf -O /home/bitsend/bitcore-livenet/bin/mynode/data/bitsend.conf" >> /usr/local/bin/new_config.sh
echo "supervisorctl restart bitsendd" >> /usr/local/bin/new_config.sh
chmod 755 /usr/local/bin/new_config.sh

# Starting Supervisor Service
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
