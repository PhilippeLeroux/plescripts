###	Détails :

Avec la version de base de l'ISO OL7 pour configurer les zones il suffisait
d'indiquer dans les fichiers `ifcfg-eth?` la zone dans avec la variable `ZONE=trusted|public`.

Une mise à jour a mis le bordel les zones sont ignorées, les fichiers `ifcfg-eth?`
renommés en `ifcfg-eth?.old`. Je pense que c'est un bug de NetworkManager.

J'ai essayé diverses configurations, mais ça n'a rien donné de concluant. Les
scripts de ce répertoire permettent de contourner le dysfonctionnement et
d'affecter correctement les zones aux interfaces.

### BUG corrigé :
Avec la version `3.8.13-118.16.2.el7uek.x86_64` d'OL7.3 le bug est corrigé, le
service qui corrige le bug n'est donc plus nécessaire.

Testé le 07/02/2017 :
Le service est désactivé sur `K2`.

15/02/2017 ajout du paramètre `-nm_workaround` au script 03_setup_infra_vm.sh pour
réactiver le workaround. Par défaut le script n'est plus appelé.

**28/02/2017** Si l'installation de l'OS se fait directement avec l'ISO OL7.3
alors les zones sont de nouveaux perdus, donc par défaut le workaround est
activé et n'est pas désactivable.
