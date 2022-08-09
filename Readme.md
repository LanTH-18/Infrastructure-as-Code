1/ Remediation use case problem statement: Provision VPS and AWS EKS to fulfill requirements below

* AWS EKS security groups allow incoming traffic only on TCP port 443: 
-> Allow worker to receive communication from the cluster control plane

* Envelope encryption for EKS Kubernetes Secrets is enabled using Amazon KMS:
-> 

* EKS control plane logging is enabled for your Amazon EKS clusters:
-> Use AWS cloudwatch to log 2 type: audit and API 

* The latest version of Kubernetes is installed on your Amazon EKS clusters.
-> set in terraform.tfvars or will be provision as latest version

* Amazon EKS configuration changes are monitored.
-> This will go with log audit

2/ IAM Role/ User:
I create a user with full permission for the sake of testing and easier to run.
However,if security is important, you can just create a user with assumeRole permission with MFA.
Then create a Role that have full access however it only trust relationship is your user.
By this, if you want to access you have to run assumeRole to get the session token.

3/ Run Script:
I also include a bash script to run the terraform. Please change it to .bat file to run or run each line in the script.