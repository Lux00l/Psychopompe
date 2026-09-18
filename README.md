#  Psychopompe (ψυχοπομπός)
## « guide des âmes »

Hermès est la figure majeure du psychopompe dans la mythologie grecque, un terme désignant littéralement le « guide des âmes ».  En tant que messager des dieux, il possède la capacité unique de traverser les frontières entre les mondes des vivants, des dieux et des morts, ce qui lui permet d’escorter les âmes des défunts vers l’Au-delà. 

Psychopompe est un des rôles d'Hermes
___

Un Orchestrateur / Arrangeur 

## Projet : 
Analyse et Routage : Il décompose la requête utilisateur en micro-tâches et dirige chaque étape vers l'agent ou l'outil spécialisé approprié (base de données, RAG, modèle de langage). 
Coordination : Il assure la fluidité des échanges de données entre les agents, gère l'état du contexte et valide la cohérence des résultats intermédiaires. 
Synthèse : Il compile les réponses finales pour fournir une sortie unique, structurée et fiable à l'utilisateur. 



Par exemple ici la première boucle pour les emails
```
start

:1. Cron déclenche le script\n(toutes les 5 minutes) ;

:HIMALAYA envelope search\n--mailbox Inbox from "luc@soulerin.net" ;

if (Emails trouvés ?) then (oui)
    :Extraire les IDs\n(Python parsing) ;
    
    while (Pour chaque email ID) is (oui)
        :HIMALAYA message read <ID> ;
        
        :Extraire le sujet\net le corps (text/plain) ;
        
        :Sanitizer le sujet\n→ Nom de session ;
        
        while (Pour chaque ligne\nnon-vide du corps) is (oui)
            :HERMES chat -q <ligne>\n--oneshot --continue <session>\n--format stream-json ;
            
            :Parser le JSON\nCollecter tous les chunks "text" ;
            
            :Ajouter "ligne ↳ réponse"\nà RESULTS_BODY ;
        endwhile (non)
        
        if (RESULTS_BODY\nnon vide ?) then (oui)
            :Envoyer l'email de réponse\nà luc@soulerin.net\n(MIMEText UTF-8) ;
            
            :HIMALAYA message compose\n--save Sent ;
        endif
        <img width="628" height="1365" alt="email_monitor_flow" src="https://github.com/user-attachments/assets/1c052983-83ed-4382-b55f-036c4b9654f9" />

        :HIMALAYA flag add <ID> --flag seen ;
        
        :HIMALAYA message move <ID>\n--to Archive ;
        
        :Log : "Email <ID> processed" ;
    endwhile (non)
    
else (non)
    :Log : "No new emails from luc@soulerin.net" ;
endif

stop

@enduml
```

