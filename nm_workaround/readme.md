###	Détails :

Avec la version de base de l'ISO OL7 pour configurer les zones il suffisait
d'indiquer dans les fichiers `ifcfg-eth?` la zone dans avec la variable `ZONE=trusted|public`.

Une mise à jour a mis le bordel les zones sont ignorées, les fichiers `ifcfg-eth?`
renommés en `ifcfg-eth?.old`. Je pense que c'est un bug de NetworkManager.

J'ai essayé diverses configurations, mais ça n'a rien donné de concluant. Les
scripts de ce répertoire permettent de contourner le disfonctionnement et
d'affecter correctement les zones aux interfaces.
