```mermaid
graph RL
            subgraph azure_bdd
            magento_bdd[(Service<br>Base de données<br>____________<br><br>Name: magento_bdd<br>type: Azure Database for MariaDB)]

    end
    subgraph Internet
        ip_ssh_public[Adresse Ip Publique: ip_ssh_public / provisoire]
        ip_app_public[Adresse Ip Publique: ip_app_public]
        ip_bdd_public[Adresse ip fournit par Azure]

    end
    ip_ssh_public -.-> subnet_vm
    subnet_vm -.-> vm_app
    
    ip_app_public -.-> subnet_gateway
    subnet_gateway -.-> magento_gateway
    magento_gateway -.-> vm_app
    
    magento_bdd -.-> ip_bdd_public
    ip_bdd_public -.-> subnet_gateway
    
    magento_stock -.-> vm_app
    magento_elastic -.-> vm_app
    
    
    subnet_gateway -.-> magento_conteneur

    subgraph brief4_grp5


    subgraph network
    subgraph monitor
magento_monitor{Service<br>Azure monitor<br>__________<br><br>}
magento_alert_disponibilite{Service<br>Alert de disponiblité<br>_______<br><br>Alerte en cas d'indispinobilité <br>de l'application.}
magento_alert_cpu{Service<br>Alert de cpu<br>_______<br><br>Alerte en cas d'usage CPU > 90% <br>sur la VM applicative.}
magento_alert_tls{Service<br>Alert de certificat<br>_______<br><br>Alerte si la date d'expiration<br> du certificat TLS est < 7 jours.}
magento_alert_stock{Service<br>Alert de stockage<br>_______<br><br>Alerte si l'espace disponible <br>sur l'espace de stockage < 10%}
end
    magento_monitor -.-> vm_app
    magento_alert_disponibilite -.-> ip_app_public
    magento_alert_cpu -.-> vm_app
    magento_alert_stock -.-> magento_stock
    magento_alert_tls -.-> magento_conteneur
    
        subgraph nsg_public_vm
            subnet_vm((subnet_vm))
        end
        subgraph nsg_public_gateway
            subnet_gateway((subnet_gateway))
        end
        subgraph app
        magento_stock[(Service<br>Espace de stockage<br>____________<br><br>Name:stock_app<br>Type:NFSv3<br>Quota: 5 Go)]
            vm_app[VM Applicative<br>___________<br><br>Name: magento_app<br>OS: debian]
magento_elastic{Service<br>Elasticsearch<br>_________<br><br>Name:magento_elastic<br>type:Elastic Cloud}


end
magento_gateway{Service<br>Gateway<br>_________<br><br>Name:magento_gateway<br>type:Gateway}
subgraph TLS
magento_key_vault{/Service<br>Key Vault<br>_____________<br><br>Name: magento_key_vault<br>type:\}
magento_stock_blob{\Service<br>Compte de stockage/}
magento_conteneur -.-> magento_stock_blob
magento_stock_blob -.-> magento_blob
magento_conteneur -.-> magento_key_vault
magento_conteneur{Service<br>Conteneur<br>_______<br><br>TLS}
magento_blob[(Service<br>Blob<br>__________<br><br>Name:magento_blob)]

end

    end
end
    classDef primary fill:#fdcfca,color:#fff;
    class nsg_public_vm,nsg_public_gateway, primary;
    
    classDef net fill:#fa8072, color:#fff;
    class subnet_gateway,subnet_vm, net;
    
    classDef secondary fill:#9932cc,color:#FFF;
    class ip_app_public,ip_ssh_public,ip_bdd_public, secondary;
    
    class magento_bdd,magento_blob,magento_stock secondary_bdd;
    classDef secondary_bdd fill:#f9f;
    
    classDef tertiary fill:#a9a9a9,stroke:#FFF,color:#FFF;
    class monitor,app,TLS,Internet,azure_bdd tertiary;
    classDef service fill:#5a4cae,color:#fff;
    class magento_gateway,magento_elastic,magento_conteneur,magento_stock_blob,magento_key_vault service;
    
    classDef moni fill:#6495ed, color:#fff, stroke:#FFFF;
    class magento_monitor,magento_alert_disponibilite,magento_alert_tls,magento_alert_stock,magento_alert_cpu, moni;
    
    classDef vm fill:#c5b2ec, color:#fff;
    class vm_app, vm;
    
    classDef fgreen fill:#a9a9a9,color:#fff,stroke:#FFFF;
    class brief4_grp5 fgreen;
    
    classDef green fill:#a9a9a9,color:#fff,stroke:#FFFF;
    class network, green;



```
