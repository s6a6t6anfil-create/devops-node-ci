mock_provider "aws" {}

variables {
  aws_account_id = "123456789012"
  ami_id         = "ami-0123456789abcdef0"
  subnet_id      = "subnet-0123456789abcdef0"
  key_name       = "optima-test-key"
}

run "ports_closed_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.app) == 0 && length(aws_vpc_security_group_ingress_rule.ssh) == 0
    error_message = "No inbound access must be created with the default configuration."
  }

  assert {
    condition     = aws_instance.pz12.instance_type == "t3.micro" && aws_instance.pz12.metadata_options[0].http_tokens == "required"
    error_message = "The plan must use one t3.micro instance with IMDSv2."
  }
}

run "temporary_access_uses_two_host_rules" {
  command = plan
  variables {
    ssh_cidr = "192.0.2.10/32"
    app_cidr = "198.51.100.20/32"
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh[0].from_port == 22 && aws_vpc_security_group_ingress_rule.app[0].from_port == 3000
    error_message = "Test access must be separated into the SSH and application ports."
  }
}

run "reject_broad_ssh" {
  command = plan
  variables {
    ssh_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.ssh_cidr]
}
