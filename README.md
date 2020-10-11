# Terraform Learning Exercise

## building a simple stack in Terraform

I've been wanting to learn a bit more about Terraform for a while - and so I decided to try and build a simple example application.
As I've had a lot of experience with AWS and Ansible - but virtually none of Terraform - it'll be interesting to see how easy it is to pick up.

## Initial impressions

Getting Terraform setup on my local machine was very easy

https://learn.hashicorp.com/collections/terraform/aws-get-started

as I already have a personal AWS account - I had an infrastructure to work off.  

I was also very impressed with the reference material - it made the translation from Ansible 'thinking' to Terraform very simple (and shows how bloated Ansible can get!)

https://registry.terraform.io/providers/hashicorp/aws/

Finally - I found the linter `tflint` (https://github.com/terraform-linters/tflint) useful for spotting issues before I applied them.

## Assumptions (or 'why this won't work if you just run it on a clean AWS account')

* I've got a domain name setup in Route 53 already - so I've hardcoded those details into the the template (it didn't seem worth the hassle of registering _another_ domain just for this exercise.   
* I've also got a keypair setup on this account - so I've added that to Lauch Config - this too will break a non-Tim AWS account

## The goal

I've used ElasticBeanstalk and CloudFormation - but never used an Autoscaling Group - so I decided to setup a 1 node ASG - with an ELB in front of it - exposing port 22.  
You'd obviously never do this in real life (why would you load balance a stateful SSH session?) but it's a more interesting challenge - as it forces me to use a VPC (as port 22 isn't an option within VPC mode) 

A nice URL - I picked `terraform.incomprehensible.co.uk` will front this endevour. 

Yes, security is a problem here - port 22 to 'the internet' is never clever - but at least we can ensure the instance doesn't have a public IP without going through the ELB - and by plonking it all on it's own VPN - it limits the damage to the rest of my vast* AWS empire 

(* may not be very vast at all)

## Running the code

`tflint` # to check the code is sane

`terraform apply -auto-approve` # to apply the config

`terraform destroy -auto-approve` # to remove it
