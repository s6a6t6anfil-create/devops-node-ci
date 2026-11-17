variable "aws_region" {
  type        = string
  description = "Approved AWS region for this isolated lab."
  default     = "eu-north-1"
  validation {
    condition     = var.aws_region == "eu-north-1"
    error_message = "This lab is intentionally limited to eu-north-1."
  }
}

variable "aws_account_id" {
  type        = string
  description = "Non-public operational input; supply in the ignored local var file."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Enter the approved 12-digit AWS account ID."
  }
}

variable "ami_id" {
  type        = string
  description = "Verified official Canonical Ubuntu 24.04 amd64 AMI in eu-north-1."
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8}([0-9a-f]{9})?$", var.ami_id))
    error_message = "Enter a valid AMI ID."
  }
}

variable "subnet_id" {
  type        = string
  description = "Existing approved public subnet with an Internet Gateway route."
  validation {
    condition     = can(regex("^subnet-[0-9a-f]{8}([0-9a-f]{9})?$", var.subnet_id))
    error_message = "Enter a valid subnet ID."
  }
}

variable "instance_type" {
  type        = string
  description = "One small x86_64 T3 for the Node and PostgreSQL containers."
  default     = "t3.micro"
  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "Use the single proposed t3.micro."
  }
}

variable "key_name" {
  type        = string
  description = "Name of a separately approved EC2 key pair in eu-north-1."
  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,255}$", var.key_name))
    error_message = "Set the EC2 key-pair name, not a file path."
  }
}

variable "private_key_path" {
  type        = string
  description = "Optional local SSH reference only; Terraform never reads it or copies the key to state."
  default     = null
  sensitive   = true
}

variable "ssh_cidr" {
  type        = string
  description = "Temporary SSH IPv4 /32; null removes the rule."
  default     = null
  validation {
    condition     = var.ssh_cidr == null ? true : (var.ssh_cidr != "0.0.0.0/32" && can(regex("^[0-9.]+/32$", var.ssh_cidr)) && can(cidrnetmask(var.ssh_cidr)))
    error_message = "SSH must be null or one specific IPv4 /32."
  }
}

variable "app_cidr" {
  type        = string
  description = "Optional client IPv4 /32 for temporary external HTTP verification."
  default     = null
  validation {
    condition     = var.app_cidr == null ? true : (var.app_cidr != "0.0.0.0/32" && can(regex("^[0-9.]+/32$", var.app_cidr)) && can(cidrnetmask(var.app_cidr)))
    error_message = "HTTP must be null or one specific IPv4 /32."
  }
}
