
#!/bin/bash

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

# Configuração do Nginx (adicionando arquivo de configuração)
echo "Configurando Nginx para o domínio: $DOMAIN"

# Criar um arquivo de configuração para o site
sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOL
upstream backend {
    server $FIVEM_IP:$FIVEM_PORT;  # IP e porta do servidor FiveM fornecido pelo usuário
}

proxy_cache_path /srv/cache levels=1:2 keys_zone=assets:48m max_size=20g inactive=2h;

server {
    listen 443 ssl;
    listen [::]:443 ssl ipv6only=on;  # Se precisar de IPv6, mantenha, senão remova.

    server_name $DOMAIN www.$DOMAIN;

    # Certificados SSL gerados pelo Certbot
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Configurações adicionais recomendadas pelo Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Configuração de cache para os arquivos
    location /files {
        proxy_pass http://backend$request_uri;
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
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Testando a configuração do Nginx
sudo nginx -t

# Reiniciando o Nginx para aplicar as alterações
sudo systemctl restart nginx

# Gerando os certificados SSL com Certbot e forçando o redirecionamento de HTTP para HTTPS
echo "Gerando certificados SSL para o domínio $DOMAIN"
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --redirect

# Confirmando que o Certbot configurou o SSL corretamente
echo "Certificados SSL gerados com sucesso!"

# Finalizando
echo "Configuração concluída para o domínio: $DOMAIN"
