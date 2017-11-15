# README

This repository is an example to using Terraform with AWS as a provider.

## How to Use

1. Install [Terraform](https://www.terraform.io/)
2. Install [Ansible](https://www.ansible.com/)
3. Create an `/.aws/configuration` file containing `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
4. Run `terraform init` on the root of one of the examples do the same for others
5. Run `terraform plan`
6. If the plan looks good, run `terraform apply`

This example is based on the examples from Terraform Up and Running. This is a great book to start learning Terraform.
