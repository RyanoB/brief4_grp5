sudo php bin/magento setup:install --base-url=http://localhost/magento2 --db-host=magento-mariadb-server.mariadb.database.azure.com --db-name=mariadb_database --db-user=magento@magento-mariadb-server --db-password=blablabla123! --admin-firstname=admin --admin-lastname=admin --admin-email=admin@admin.com --admin-user=admin --admin-password=admin123 --language=en_US --currency=USD --timezone=America/Chicago --use-rewrites=1 --search-engine=elasticsearch7 --elasticsearch-host=2aaa992d3eef4ef8bbd75c9ddd77bd13.eastus.azure.elastic-cloud.com --elasticsearch-port=443 --elasticsearch-index-prefix=magento2 --elasticsearch-timeout=15