
# Budget outputs

output "m_a_min" {value = var.m_a_min}
output "m_a_low" {value = var.m_a_low}
output "m_a_med" {value = var.m_a_med}
output "m_a_high" {value = var.m_a_high}

output "default_budget_thresh_pct_low" {value = var.default_budget_thresh_pct_low}
output "default_budget_thresh_pct_mid" {value = var.default_budget_thresh_pct_mid}
output "default_budget_thresh_pct_high" {value = var.default_budget_thresh_pct_high}
output "default_budget_thresh_pct_100" {value = var.default_budget_thresh_pct_100}
output "default_budget_thresh_spend_basis" {value = var.default_budget_thresh_spend_basis}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Budget information
variable "m_a_min" {
  description = "Budget minimal monthly and annual amounts."
  type        = list(number)
  default     = [100, 1200]
}

variable "m_a_low" {
  description = "Budget low monthly and annual amounts."
  type        = list(number)
  default     = [200, 2400]
}

variable "m_a_med" {
  description = "Budget medium monthly and annual amounts."
  type        = list(number)
  default     = [500, 6000]
}

variable "m_a_high" {
  description = "Budget high monthly and annual amounts."
  type        = list(number)
  default     = [1000, 12000]
}

variable "default_budget_thresh_pct_low" {
  description = "Budget threshold percent: low."
  type        = number
  default     = 0.5
}

variable "default_budget_thresh_pct_mid" {
  description = "Budget threshold percent: mid."
  type        = number
  default     = 0.75
}

variable "default_budget_thresh_pct_high" {
  description = "Budget threshold percent: high."
  type        = number
  default     = 0.9
}

variable "default_budget_thresh_pct_100" {
  description = "Budget threshold percent: 100%"
  type        = number
  default     = 1.0
}

variable "default_budget_thresh_spend_basis" {
  description = "Budget threshold spend basis: CURRENT_SPEND, FORECASTED_SPEND."
  type        = string
  default     = "CURRENT_SPEND"   # "CURRENT_SPEND", "FORECASTED_SPEND"
}