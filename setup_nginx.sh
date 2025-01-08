#!/bin/bash

# Verificar se o sistema é Ubuntu 20.04
if [[ "$(lsb_release -r | awk '{print $2}')" != "20.04" ]]; then
    echo "Este script só pode ser executado no Ubuntu 20.04."
    exit 1
fi

# Criar o diretório de cache se não existir
sudo mkdir -p /srv/cache

# Solicitar domínio do usuário
echo "Digite o domínio para o Certbot (ex: proxy.filadelfiagroup.com.br): "
read DOMAIN

# Solicitar IP e porta do servidor FiveM
echo "Digite o IP do servidor FiveM (ex: 131.196.196.21): "
read FIVEM_IP
echo "Digite a porta do servidor FiveM (ex: 30120): "
read FIVEM_PORT

# Atualizando pacotes do sistema
sudo apt update -y
sudo apt upgrade -y

# Instalando Nginx e Certbot
sudo apt install nginx -y
sudo apt install certbot python3-certbot-nginx -y

# Garantir que o arquivo default esteja limpo e apenas com a configuração necessária
echo "Configurando o arquivo default do Nginx..."

# Limpar e configurar o arquivo default com as definições necessárias
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    upstream backend {
        server $FIVEM_IP:$FIVEM_PORT;  # IP e porta do servidor FiveM fornecido pelo usuário
    }

    # Redirecionar HTTP para HTTPS
    if (\$host = www.$DOMAIN) {
        return 301 https://\$host\$request_uri;
    }

    if (\$host = $DOMAIN) {
        return 301 https://\$host\$request_uri;
    }

    listen 80;
    listen [::]:80;
    server_name www.$DOMAIN $DOMAIN;
    return 404; # managed by Certbot
}

proxy_cache_path /srv/cache levels=1:2 keys_zone=assets:48m max_size=20g inactive=2h;

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name $DOMAIN;

    # Certificados SSL gerados pelo Certbot
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Verificar se o arquivo de configurações SSL existe e incluir o necessário
    if [ -f "/etc/letsencrypt/options-ssl-nginx.conf" ]; then
        include /etc/letsencrypt/options-ssl-nginx.conf;
    else
        echo "Arquivo /etc/letsencrypt/options-ssl-nginx.conf não encontrado. Certifique-se de que o Certbot está instalado corretamente."
    fi

    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Configuração de cache para os arquivos
    location /files {
        proxy_pass http://backend\$request_uri;
        add_header X-Cache-Status \$upstream_cache_status;
        proxy_cache_lock on;
        proxy_cache assets;
        proxy_cache_valid 1y;
        proxy_cache_key \$request_uri\$is_args\$args;
        proxy_cache_revalidate on;
        proxy_cache_min_uses 1;
    }
}
EOL

# Ativando o site e criando o link simbólico
sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

# Testando a configuração do Nginx
sudo nginx -t

# Reiniciando o Nginx para aplicar as alterações
sudo systemctl restart nginx

# Solicitar o e-mail e gerar o SSL com Certbot
echo "Gerando certificados SSL para o domínio $DOMAIN"
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --redirect --agree-tos --no-eff-email --email usuario@example.com

# Confirmando que o Certbot configurou o SSL corretamente
echo "Certificados SSL gerados com sucesso!"

# Finalizando
echo "Configuração concluída para o domínio: $DOMAIN"
