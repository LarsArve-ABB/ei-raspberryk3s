# EdgeInsight customer template repo
Top level doc repo:**[EdgeInsight main repo](https://github.com/ABB-PAEN/edgeinsight)**
\
\
\
This repo contains the latest deployment files for deploying EdgeInsight with gitops. Create a new repo in github based on this template repo, and update the following accordingly before deploying:

- **applicationset.yaml**: update the repoURL to the customer (https://github.com/ABB-PAEN/customer-site.git)
- remove the folders in /edgeinsight-apps/* for the components you do not want to deploy

