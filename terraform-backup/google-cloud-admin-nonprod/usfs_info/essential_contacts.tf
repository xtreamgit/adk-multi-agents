
output "essential_contact_email_list" {value = var.essential_contact_email_list}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

variable "essential_contact_email_list" {
  description = "Essential contact email list."
  type        = list(string)
  default     = [
    "andrew.stratton@usda.gov",
    "cameron.johnson3@usda.gov",
    "carlos.ramirez@usda.gov",
    "hector.dejesus@usda.gov",
    "nathan.suon@usda.gov",

    # "joel.thompson@usda.gov",
    # "SameedUddin.Mohammed@usda.gov",
  ]
}