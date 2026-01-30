# Agent Tool Requirements Analysis
**Date:** January 23-24, 2026  
**Purpose:** Analysis of 28 use case scenarios identifying additional tools needed beyond current RAG agent capabilities

---

## Current Agent Tools
- `rag_query`, `rag_multi_query`, `list_corpora`, `get_corpus_info`
- `create_corpus`, `add_data`, `delete_corpus`, `delete_document`, `retrieve_document`

---

## Summary of 28 Use Cases & Required Tools

### 1. Invoice Monitoring & Alerts
**Tools:** `monitor_corpus_changes`, `extract_structured_data`, `send_alert`

### 2. Budget Variance Monitoring
**Tools:** `extract_financial_data`, `calculate_variance`, `send_alert`

### 3. Audit Report Compilation
**Tools:** `query_transactions`, `aggregate_data`, `generate_report`

### 4. Tax Document Gathering
**Tools:** `filter_by_metadata`, `extract_tax_data`, `generate_tax_summary`

### 5. HR Onboarding & Q&A
**Tools:** `classify_hr_query`, `retrieve_personalized_info`, `format_conversational_response`

### 6. Certification Expiration Monitoring
**Tools:** `extract_certification_data`, `schedule_expiration_checks`, `send_alert`

### 7. Salary Analysis & Market Comparison
**Tools:** `extract_salary_data`, `analyze_compensation_data`, `generate_compensation_report`

### 8. Performance Review Synthesis
**Tools:** `extract_performance_data`, `analyze_growth_patterns`, `generate_development_plan`

### 9. Contract Renewal Monitoring
**Tools:** `extract_contract_data`, `schedule_renewal_checks`, `send_stakeholder_notification`

### 10. Contract Clause Comparison
**Tools:** `extract_contract_clauses`, `compare_clause_variations`, `generate_clause_analysis_report`

### 11. Legal Case Risk Assessment
**Tools:** `search_similar_cases`, `analyze_case_outcomes`, `generate_risk_assessment`

### 12. Policy Compliance Checking
**Tools:** `extract_policy_requirements`, `validate_against_regulations`, `generate_compliance_report`

### 13. Customer Health Monitoring
**Tools:** `extract_sentiment_data`, `analyze_customer_risk`, `generate_customer_alerts`

### 14. Sales Proposal Generation
**Tools:** `match_case_studies`, `extract_success_metrics`, `generate_proposal_document`

### 15. Competitive Intelligence
**Tools:** `extract_competitive_data`, `analyze_competitive_position`, `generate_positioning_report`

### 16. Renewal Prediction
**Tools:** `extract_renewal_history`, `identify_renewal_patterns`, `generate_renewal_forecast`

### 17. Project Status Monitoring
**Tools:** `extract_project_data`, `monitor_project_health`, `send_project_alerts`

### 18. SLA Compliance Monitoring
**Tools:** `extract_sla_metrics`, `calculate_sla_compliance`, `generate_performance_scorecard`

### 19. Incident Pattern Analysis
**Tools:** `extract_incident_data`, `identify_recurring_patterns`, `generate_rca_recommendations`

### 20. Resource Capacity Planning
**Tools:** `extract_utilization_metrics`, `analyze_utilization_trends`, `generate_capacity_plan`

### 21. Documentation Gap Analysis
**Tools:** `extract_questions_data`, `match_to_documentation`, `generate_documentation_roadmap`

### 22. Release Notes Comparison
**Tools:** `extract_release_data`, `compare_versions`, `generate_whats_new_summary`

### 23. Expert Routing
**Tools:** `extract_expertise_profiles`, `match_question_to_expert`, `route_and_notify_expert`

### 24. Standards Verification
**Tools:** `extract_procedure_data`, `compare_to_standards`, `generate_alignment_report`

### 25. Treatment Contraindication Alerts (Healthcare)
**Tools:** `extract_patient_data`, `check_contraindications`, `alert_healthcare_provider`

### 26. Systematic Review Compilation (Medical)
**Tools:** `extract_research_data`, `synthesize_evidence`, `generate_systematic_review`

### 27. Clinical Trial Matching (Healthcare)
**Tools:** `extract_trial_criteria`, `match_patient_to_trials`, `generate_trial_recommendations`

### 28. Drug Interaction Checking (Healthcare)
**Tools:** `extract_prescription_data`, `check_drug_interactions`, `generate_interaction_alert`

---

## Common Tool Patterns Identified

### Data Extraction Tools (9 variations)
Extract structured data from documents: financial, certification, patient, contract, performance, etc.

### Analysis/Comparison Tools (9 variations)
Analyze patterns, compare against standards/benchmarks, calculate metrics, identify risks

### Report/Alert Generation Tools (10 variations)
Generate formatted reports, send notifications, create actionable recommendations

---

**Note:** Full detailed specifications for each tool are available in the complete conversation history (January 23-24, 2026).


# Agent Tool Requirements: 28 Advanced Use Cases

This document details the tool requirements for 28 advanced RAG agent use cases. For each use case, three specific tools are defined with their purpose, functionality, parameters, and a complete workflow example.

---
The key is combining retrieval with analysis, synthesis, and action - not just answering questions but proactively monitoring, alerting, and generating outputs based on corpus data.		

---



## 1. Invoice Monitoring & Alerting
**Goal:** Implement invoice monitoring to detect new documents and alert on specific criteria.

### Additional Tools Needed
1.  **`monitor_corpus_changes`**
    * **Purpose:** Detect when new documents are added to a corpus.
    * **Functionality:**
        * Track document additions to specific corpora (e.g., "invoices").
        * Support event-based triggers or scheduled polling.
        * Return list of newly added documents since last check.
        * Include metadata like timestamp, document ID, and file name.
    * **Parameters:**
        * `corpus_name` - Which corpus to monitor.
        * `since_timestamp` - Check for changes since this time.
        * `document_types` - Optional filter for specific file types.

2.  **`extract_structured_data`**
    * **Purpose:** Parse and extract specific fields from documents.
    * **Functionality:**
        * Extract structured data from semi-structured documents (invoices, forms, receipts).
        * Parse key-value pairs: invoice number, date, amount, payment terms, vendor info.
        * Return data in structured format (JSON) for condition checking.
        * Handle multiple document formats (PDF, scanned images, spreadsheets).
    * **Parameters:**
        * `corpus_name` - Source corpus.
        * `document_id` - Specific document to parse.
        * `fields` - List of fields to extract (e.g., `["amount", "payment_terms", "due_date"]`).

3.  **`send_alert`**
    * **Purpose:** Send notifications when specific conditions are met.
    * **Functionality:**
        * Send alerts via multiple channels (email, Slack, webhooks, SMS).
        * Support templated messages with dynamic data.
        * Include alert severity levels (info, warning, critical).
        * Track alert history and prevent duplicate alerts.
    * **Parameters:**
        * `alert_type` - Channel (email, slack, webhook).
        * `recipients` - Who receives the alert.
        * `subject` - Alert title/subject.
        * `message` - Alert content (supports templates).
        * `severity` - Alert priority level.
        * `data` - Structured data to include (invoice details, amounts, etc.).

### Complete Workflow Example
* **monitor_corpus_changes** → Detect new invoice added.
* **extract_structured_data** → Parse `payment_terms = "120 days"`, `amount = "$50,000"`.
* **Condition Check (agent logic)** → Payment terms > 90 days? (Yes). Amount > threshold? (Yes).
* **send_alert** → Email finance team: "High-value invoice with extended payment terms detected".

---

## 2. Budget Variance Monitoring
**Goal:** Implement budget variance monitoring and alerting.

### Additional Tools Needed
1.  **`extract_financial_data`**
    * **Purpose:** Extract numerical and financial data from reports and documents.
    * **Functionality:**
        * Parse financial statements, budget reports, and quarterly documents.
        * Extract structured financial data: actual spending, budgeted amounts, categories, time periods.
        * Handle various formats (Excel, PDF financial reports, CSV exports).
        * Organize data by cost centers, departments, projects, or accounts.
        * Support time-series data extraction (Q1, Q2, Q3, Q4).
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "finance", "quarterly-reports").
        * `document_id` or `document_name` - Specific report to analyze.
        * `data_types` - Fields to extract (e.g., `["actual_spending", "budgeted_amount", "category", "quarter"]`).
        * `time_period` - Specify which quarter/period to extract.

2.  **`calculate_variance`**
    * **Purpose:** Perform financial calculations and variance analysis.
    * **Functionality:**
        * Calculate variance between actual vs budgeted amounts.
        * Compute percentage deviations (e.g., ">10% threshold").
        * Compare across time periods (QoQ, YoY comparisons).
        * Support multiple variance types: absolute difference, percentage, favorable/unfavorable.
        * Aggregate data by category, department, or other dimensions.
        * Generate variance summaries and flag anomalies.
    * **Parameters:**
        * `actual_values` - Array of actual spending data.
        * `budgeted_values` - Array of budgeted amounts.
        * `threshold_percentage` - Alert threshold (e.g., 10).
        * `comparison_type` - Type of calculation (percentage_variance, absolute_variance).
        * `group_by` - Optional grouping (department, category, project).

3.  **`send_alert`**
    * **Purpose:** Send notifications when variance thresholds are exceeded.
    * **Functionality:**
        * Send alerts via multiple channels (email, Slack, webhooks, SMS).
        * Support templated financial alert messages.
        * Include variance details: amounts, percentages, affected categories.
        * Attach supporting data or report excerpts.
        * Priority levels based on severity of deviation.
        * Track alert history to prevent alert fatigue.
    * **Parameters:**
        * `alert_type` - Channel (email, slack, webhook, dashboard).
        * `recipients` - Finance team, budget owners, department heads.
        * `subject` - Alert title (e.g., "Budget Variance Alert - Q3 2026").
        * `message` - Detailed alert content with variance information.
        * `severity` - Priority level based on deviation magnitude.
        * `variance_data` - Structured data showing actual vs budget, percentage, categories affected.

### Complete Workflow Example
* **rag_query** → Query "quarterly-reports" corpus for Q3 financial data.
* **extract_financial_data** → Parse out: `Actual=$1.2M`, `Budget=$1M` for Marketing.
* **calculate_variance** → Compute: +20% variance (exceeds 10% threshold).
* **send_alert** → Email CFO: "Marketing spending 20% over budget ($200K variance) in Q3".

---

## 3. Audit Report Compilation
**Goal:** Implement comprehensive audit report generation for vendor/project transactions.

### Additional Tools Needed
1.  **`query_transactions`**
    * **Purpose:** Advanced filtering and search of transaction data with structured queries.
    * **Functionality:**
        * Filter transactions by vendor name, vendor ID, project code, date range.
        * Support complex queries with multiple criteria (AND/OR logic).
        * Search across transaction metadata: amounts, dates, categories, approvers, invoice numbers.
        * Return structured transaction records with all relevant fields.
        * Handle large result sets with pagination.
        * Sort and order results by date, amount, or other fields.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "transactions", "financial-records").
        * `filters` - Query criteria: `{"vendor": "Acme Corp", "date_range": "2025-Q1", "project_id": "PRJ-001"}`.
        * `fields` - Which transaction fields to retrieve.
        * `sort_by` - Order results (date, amount, vendor).
        * `limit` - Maximum results to return.

2.  **`aggregate_data`**
    * **Purpose:** Compile, summarize, and organize transaction data for analysis.
    * **Functionality:**
        * Aggregate transactions by vendor, project, time period, or category.
        * Calculate totals, subtotals, averages, and other statistical measures.
        * Group related transactions for comprehensive view.
        * Identify patterns: duplicate payments, unusual amounts, frequency analysis.
        * Generate summary statistics: total count, sum, min/max amounts, date ranges.
        * Cross-reference transactions with related documents (invoices, POs, contracts).
    * **Parameters:**
        * `transaction_data` - Raw transaction records from query_transactions.
        * `group_by` - Aggregation dimension (vendor, project, month, category).
        * `calculations` - Metrics to compute (sum, count, average, variance).
        * `include_details` - Whether to include individual transactions or just summaries.
        * `anomaly_detection` - Flag unusual patterns or outliers.

3.  **`generate_report`**
    * **Purpose:** Create formatted, professional audit reports from compiled data.
    * **Functionality:**
        * Generate reports in multiple formats (PDF, Excel, Word, HTML).
        * Apply standard audit report templates with company branding.
        * Include executive summary, detailed findings, supporting data tables.
        * Add visualizations: charts, graphs, trend lines for transaction patterns.
        * Support customizable sections: cover page, methodology, findings, recommendations.
        * Include audit trail: who generated report, when, what data was included.
        * Auto-generate table of contents, page numbers, section headers.
    * **Parameters:**
        * `aggregated_data` - Compiled transaction summaries from aggregate_data.
        * `report_type` - Template to use (vendor_audit, project_audit, compliance_audit).
        * `output_format` - Format preference (PDF, XLSX, DOCX).
        * `sections` - Which sections to include (summary, details, charts, appendix).
        * `title` - Report title (e.g., "Acme Corp Vendor Audit - 2025 Q1-Q4").
        * `recipient_info` - For whom the report is prepared.

### Complete Workflow Example
* **rag_query** → "Find all documents in transactions corpus related to vendor Acme Corp".
* **query_transactions** → Filter transactions: `vendor="Acme Corp"`, `date_range="2025"`.
* **aggregate_data** → Compile: Total=$2.4M, 156 transactions, grouped by quarter.
* **generate_report** → Create PDF audit report titled "Acme Corp Vendor Audit Report - FY 2025".

---

## 4. Tax Document Gathering & Reporting
[cite_start]**Goal:** Implement tax year document gathering and summary report preparation[cite: 10].

### Additional Tools Needed
1.  **`filter_by_metadata`**
    * **Purpose:** Advanced document filtering based on date, type, and other metadata.
    * **Functionality:**
        * Filter documents by specific tax year or date range (e.g., "2025-01-01 to 2025-12-31").
        * Filter by document type (receipts, invoices, statements, W-2s, 1099s).
        * Search by vendor/payer name, amount ranges, category tags.
        * Support multiple filter criteria simultaneously.
        * Handle different date formats and fiscal year vs calendar year.
        * Return organized document lists with metadata.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "tax-docs", "invoices", "receipts").
        * `date_range` - Tax year or specific date range (e.g., "2025", "2025-Q1").
        * `document_types` - Types to include (`["receipt", "invoice", "statement", "tax_form"]`).
        * `categories` - Expense categories (business_travel, office_supplies, etc.).
        * `amount_range` - Optional min/max amount filter.

2.  **`extract_tax_data`**
    * **Purpose:** Extract tax-relevant financial information from documents.
    * **Functionality:**
        * Parse receipts, invoices, and statements for tax-deductible information.
        * Extract key tax fields: date, amount, vendor/payer, expense category, payment method.
        * Identify tax form data: SSN/EIN, income amounts, deductions, credits.
        * Categorize expenses by IRS categories (Schedule C, etc.).
        * Handle OCR for scanned receipts and paper documents.
        * Detect and flag potential errors or missing information.
        * Calculate totals by category.
    * **Parameters:**
        * `corpus_name` - Source corpus.
        * `document_ids` - List of documents from filter_by_metadata.
        * `extraction_fields` - Data to extract (`["date", "amount", "vendor", "category", "tax_category"]`).
        * `tax_year` - Relevant tax year for validation.
        * `categorization_rules` - How to categorize expenses for tax purposes.

3.  **`generate_tax_summary`**
    * **Purpose:** Create comprehensive tax summary reports from gathered documents.
    * **Functionality:**
        * Generate tax-ready summary reports in multiple formats (PDF, Excel, CSV).
        * Create IRS-compliant documentation summaries.
        * Organize by tax categories: income, deductions, credits, expenses.
        * Calculate category totals and subtotals.
        * Include supporting document references with links.
        * Generate visualizations: spending by category, monthly trends.
        * Export data in tax software-compatible formats (TurboTax, H&R Block).
    * **Parameters:**
        * `extracted_data` - Financial data from extract_tax_data.
        * `tax_year` - Year for the report.
        * `report_type` - Template (personal_tax, business_tax, Schedule_C, expense_report).
        * `output_format` - Format preference (PDF, XLSX, CSV, tax_software_export).
        * `include_sections` - Sections to include (summary, itemized_list, category_breakdown, charts).
        * `taxpayer_info` - Name, SSN/EIN, filing status for report header.

### Complete Workflow Example
* **list_corpora** → Identify relevant corpora: "receipts", "invoices".
* **filter_by_metadata** → Find all documents from 2025.
* **extract_tax_data** → Parse documents: `Business meals=$8,450`, `Office supplies=$3,200`.
* **generate_tax_summary** → Create report: "2025 Tax Year Summary" with category totals and itemized lists.

---

## 5. HR Onboarding & Q&A
[cite_start]**Goal:** Implement conversational HR support for new employees querying policies and procedures[cite: 34].

### Additional Tools Needed
1.  **`classify_hr_query`**
    * **Purpose:** Understand and categorize employee questions to route to correct information.
    * **Functionality:**
        * Classify employee questions into HR categories (benefits, payroll, PTO, policies, onboarding).
        * Identify query intent: informational, procedural, policy clarification, benefits enrollment.
        * Detect multi-part questions requiring multiple corpus searches.
        * Recognize employee context: role, department, location for personalized responses.
        * Flag urgent vs routine inquiries.
        * Suggest related topics employee might need.
    * **Parameters:**
        * `question` - Employee's natural language question.
        * `employee_context` - Employee metadata (role, department, hire_date, location).
        * `conversation_history` - Previous questions in session for context.
        * `return_categories` - Return ranked list of relevant HR categories.

2.  **`retrieve_personalized_info`**
    * **Purpose:** Fetch role-specific and personalized HR information.
    * **Functionality:**
        * Retrieve policies/procedures specific to employee's role, department, or location.
        * Filter benefits information based on eligibility (full-time, part-time, contractor).
        * Provide location-specific information (state laws, office policies, local benefits).
        * Access role-specific onboarding checklists and requirements.
        * Return manager contact info, team structures, and reporting relationships.
    * **Parameters:**
        * `corpus_name` - HR corpus to query.
        * `query_categories` - Categories from classify_hr_query (`["benefits", "pto_policy"]`).
        * `employee_profile` - Employee details for personalization (role, department, location, hire_date).
        * `filter_criteria` - Additional filters (eligibility_type, employment_status).

3.  **`format_conversational_response`**
    * **Purpose:** Present HR information in clear, conversational, employee-friendly format.
    * **Functionality:**
        * Convert formal policy language into easy-to-understand explanations.
        * Structure responses with clear sections: summary, details, action items, deadlines.
        * Include relevant links to full policies, enrollment portals, forms.
        * Add contextual help: "Next steps", "Related questions", "Who to contact".
        * Format complex information (benefits tables, PTO accrual schedules) clearly.
        * Provide examples when helpful (e.g., "If you were hired on Jan 15, your benefits start Feb 1").
    * **Parameters:**
        * `retrieved_data` - Information from retrieve_personalized_info.
        * `question` - Original employee question.
        * `response_style` - Tone (friendly, formal, concise, detailed).
        * `include_sections` - Which sections to include (summary, details, action_items, related_info, contacts).
        * `add_examples` - Whether to include practical examples.

### Complete Workflow Example
* **New employee asks:** "When do my health benefits start?"
* **classify_hr_query** → Categories: `["benefits_enrollment"]`, Intent: `informational`.
* **retrieve_personalized_info** → Query HR corpus with context (hire_date=Jan 15); result: starts 1st of month after 30 days.
* **format_conversational_response** → "Your health benefits will begin on March 1st... enroll by Feb 15th."

---

## 6. Certification Expiration Monitoring
[cite_start]**Goal:** Implement employee certification monitoring with proactive expiration alerts[cite: 38].

### Additional Tools Needed
1.  **`extract_certification_data`**
    * **Purpose:** Parse and extract certification details and expiration dates.
    * **Functionality:**
        * Extract certification information: name, issuing organization, issue date, expiration date.
        * Parse various document formats (PDFs, scanned certificates, spreadsheets).
        * Handle multiple certifications per employee.
        * Identify certification types: professional licenses, safety training, compliance certifications.
        * Extract employee details: name, employee ID, department, role.
        * Validate date formats and flag missing or invalid expiration dates.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "certifications", "employee-records").
        * `document_ids` - Specific documents to parse or all documents.
        * `certification_fields` - Fields to extract (`["cert_name", "employee_id", "issue_date", "expiration_date", "status"]`).
        * `employee_filter` - Optional: specific employees or departments.

2.  **`schedule_expiration_checks`**
    * **Purpose:** Monitor certification dates and identify those expiring within specified timeframe.
    * **Functionality:**
        * Calculate days until expiration for all certifications.
        * Identify certifications expiring within alert threshold (30 days, 60 days, etc.).
        * Support multiple alert windows (30-day warning, 7-day urgent, expired).
        * Schedule recurring checks (daily, weekly) to monitor expiration dates.
        * Track which alerts have already been sent to avoid duplicates.
        * Generate priority lists: urgent (expiring soon), warning, expired.
    * **Parameters:**
        * `certification_data` - Extracted certification records from extract_certification_data.
        * `alert_thresholds` - When to alert (`["30_days", "7_days", "expired"]`).
        * `check_frequency` - How often to run checks (daily, weekly).
        * `current_date` - Reference date for calculations.
        * `group_by` - Organize alerts by (employee, department, certification_type).

3.  **`send_alert`**
    * **Purpose:** Send expiration notifications to employees, managers, and HR.
    * **Functionality:**
        * Send alerts via multiple channels (email, Slack, SMS, HR system).
        * Support role-based notifications: employee, manager, HR admin, compliance officer.
        * Customize message templates by urgency level and recipient type.
        * Include certification details: name, expiration date, days remaining, renewal instructions.
        * Provide actionable items: renewal links, training schedules, contact information.
        * Track alert delivery status and confirmation.
    * **Parameters:**
        * `alert_type` - Channel (email, slack, sms, hr_dashboard).
        * `recipients` - Who receives alert (employee, manager, hr_team, compliance_officer).
        * `certification_info` - Details of expiring certifications.
        * `urgency_level` - Priority (warning_30_days, urgent_7_days, expired).
        * `message_template` - Template to use based on recipient and urgency.
        * `include_actions` - Renewal links, training registration, contact info.

### Complete Workflow Example
* **get_corpus_info** → Check "certifications" corpus.
* **extract_certification_data** → Parse certifications: names, dates.
* **schedule_expiration_checks** → Find certs expiring by Feb 23 (30 days).
* **send_alert** → Email employee: "Your CPR certification expires Feb 15. Click here to renew."

---

## 7. Salary Analysis & Market Comparison
[cite_start]**Goal:** Implement salary data analysis and market comparison reporting[cite: 43].

### Additional Tools Needed
1.  **`extract_salary_data`**
    * **Purpose:** Parse and extract structured compensation data from HR documents.
    * **Functionality:**
        * Extract salary information: employee role, title, salary, bonuses, total compensation.
        * Parse compensation from various sources (HR systems, payroll reports, offer letters).
        * Normalize job titles to standard categories for comparison.
        * Extract additional factors: years of experience, location, department, education level.
        * Handle different compensation formats: hourly, annual, commission-based.
        * Include benefits data: stock options, 401k match, health insurance value.
        * Organize data by role hierarchy and job families.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "compensation", "hr-records", "payroll").
        * `document_ids` - Specific documents to parse.
        * `data_fields` - Fields to extract (`["role", "title", "base_salary", "bonus", "total_comp", "experience", "location"]`).
        * `anonymize` - Whether to remove personally identifiable information.
        * `role_normalization` - Apply standard role categorization.

2.  **`analyze_compensation_data`**
    * **Purpose:** Perform statistical analysis and market benchmarking on salary data.
    * **Functionality:**
        * Calculate salary statistics by role: mean, median, percentiles.
        * Compare internal salaries to external market data from corpus.
        * Identify compensation gaps: gender pay equity, role parity, geographic differences.
        * Analyze salary ranges and distributions by department, seniority, location.
        * Calculate cost-of-living adjustments for different locations.
        * Identify outliers: underpaid or overpaid positions.
        * Generate competitive positioning: below market, at market, above market.
    * **Parameters:**
        * `internal_salary_data` - Company salary data from extract_salary_data.
        * `market_data_corpus` - External market data corpus name (e.g., "market-surveys").
        * `comparison_factors` - What to compare (`["role", "experience_level", "location", "industry"]`).
        * `statistical_measures` - Calculations to perform (`["mean", "median", "percentile_ranges", "variance"]`).
        * `benchmark_sources` - Market data sources to use for comparison.

3.  **`generate_compensation_report`**
    * **Purpose:** Create comprehensive salary analysis and market comparison reports.
    * **Functionality:**
        * Generate executive reports in multiple formats (PDF, PPT).
        * Create visualizations: salary distribution charts, box plots, salary distributions.
        * Include market positioning analysis with visual indicators.
        * Generate role-specific reports: individual role cards with market data.
        * Create equity analysis reports highlighting pay gaps.
        * Include recommendations: salary adjustments, market corrections, budget implications.
    * **Parameters:**
        * `analyzed_data` - Analysis results from analyze_compensation_data.
        * `report_type` - Template (executive_summary, detailed_analysis, equity_report).
        * `output_format` - Format preference (PDF, XLSX, PPTX).
        * `include_visualizations` - Chart types.
        * `confidentiality_level` - Detail level (executive_summary, manager_view, detailed_hr).
        * `sections` - Report sections (`["market_position", "equity_analysis", "recommendations", "budget_impact"]`).

### Complete Workflow Example
* **rag_query** → Query "compensation" and "market-surveys" corpora.
* **extract_salary_data** → Parse employee records.
* **analyze_compensation_data** → Calculate: Internal median $125K vs Market $135K.
* **generate_compensation_report** → Create report: "Company is 5% below market overall... $2.1M budget needed."

---

## 8. Performance Review Synthesis & Growth Analysis
[cite_start]**Goal:** Implement historical performance review analysis and development planning[cite: 48].

### Additional Tools Needed
1.  **`extract_performance_data`**
    * **Purpose:** Parse and extract structured data from performance review documents.
    * **Functionality:**
        * Extract metrics, ratings, qualitative feedback; identify review periods.
        * Parse qualitative feedback: manager comments, peer reviews, self-assessments.
        * Identify review periods: quarterly, annual, mid-year reviews with dates.
        * Extract career progression data: promotions, role changes, salary adjustments.
        * Capture development goals and action items from past reviews.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "performance-reviews").
        * `employee_id` - Specific employees or all employees.
        * `date_range` - Review period to analyze (e.g., "last_3_years").
        * `data_fields` - Fields to extract (`["ratings", "feedback", "goals", "competencies"]`).
        * `include_qualitative` - Whether to extract text feedback in addition to scores.

2.  **`analyze_growth_patterns`**
    * **Purpose:** Identify trends, patterns, and development needs from historical review data.
    * **Functionality:**
        * Track performance trends; identify competency gaps and growth areas.
        * Identify trends, patterns, and development needs from historical review data.
        * Recognize growth areas: competencies showing improvement trajectory.
        * Detect career readiness: employees ready for promotion or new responsibilities.
        * Compare against benchmarks; predict future trajectories.
    * **Parameters:**
        * `performance_data` - Extracted review data.
        * `analysis_type` - Type of analysis (trend_analysis, gap_analysis).
        * `time_period` - How far back to analyze (3_years, 5_years).
        * `comparison_benchmarks` - Compare against role expectations or peer averages.
        * `pattern_detection` - Identify improvement trends, skill gaps, risk factors.

3.  **`generate_development_plan`**
    * **Purpose:** Create personalized development recommendations and growth plans.
    * **Functionality:**
        * Generate individualized plans; recommend training/mentoring.
        * Prioritize development needs: critical skills, high-impact areas.
        * Create roadmaps with timelines and milestones.
        * Suggest resources: courses, certifications, books, mentors, projects.
    * **Parameters:**
        * `growth_analysis` - Analysis results from analyze_growth_patterns.
        * `employee_data` - Employee context (role, career goals).
        * `plan_type` - Type of output (individual_dev_plan, team_summary).
        * `output_format` - Format preference (PDF, interactive_dashboard).
        * `time_horizon` - Planning period (6_months, 1_year).
        * `include_sections` - Sections (`["summary", "development_areas", "recommended_actions"]`).

### Complete Workflow Example
* **rag_query** → Query reviews for Sarah Johnson (2023-2025).
* **extract_performance_data** → Parse ratings and feedback.
* **analyze_growth_patterns** → Trend: Technical skills up, Leadership needs work.
* **generate_development_plan** → Create plan: "Priority: Leadership development training by Q2."

---

## 9. Contract Renewal Monitoring
[cite_start]**Goal:** Implement contract scanning and proactive renewal notifications[cite: 53].

### Additional Tools Needed
1.  **`extract_contract_data`**
    * **Purpose:** Parse and extract critical contract information including renewal dates.
    * **Functionality:**
        * Extract metadata (parties, dates), terms, financial info.
        * Detect auto-renewal/opt-out clauses; normalize contract types.
        * Identify stakeholders: contract owner, approver, legal contact.
        * Extract financial terms: contract value, payment terms, renewal pricing.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "contracts").
        * `document_ids` - Specific contracts to parse.
        * `extraction_fields` - Fields to extract (`["contract_id", "parties", "renewal_date", "notice_period", "value"]`).
        * `contract_types` - Filter by type (vendor, service, license, lease).

2.  **`schedule_renewal_checks`**
    * **Purpose:** Monitor contract renewal dates and identify those requiring action.
    * **Functionality:**
        * Calculate days until renewal; account for notice periods.
        * Support multiple alert thresholds (90-day, 60-day, 30-day).
        * Track notification history to avoid duplicate alerts.
        * Flag high-priority contracts: high value, critical vendors.
    * **Parameters:**
        * `contract_data` - Extracted contract records.
        * `alert_thresholds` - When to notify (`["90_days", "60_days", "30_days"]`).
        * `check_frequency` - How often to run monitoring (daily, weekly).
        * `current_date` - Reference date for calculations.
        * `priority_rules` - Flag high-priority based on value or vendor.

3.  **`send_stakeholder_notification`**
    * **Purpose:** Send renewal reminders to appropriate stakeholders with context.
    * **Functionality:**
        * Send notifications via multiple channels; route to specific roles.
        * Customize notifications by role and urgency level.
        * Include contract details: parties, value, renewal date, action items.
        * Provide actionable options: renew, renegotiate, terminate.
        * Attach relevant documents: current contract, renewal terms.
    * **Parameters:**
        * `notification_type` - Channel (email, slack, calendar).
        * `stakeholders` - Recipients with roles (contract_owner, legal, procurement).
        * `contract_info` - Contract details requiring action.
        * `urgency_level` - Priority (routine, attention, urgent).
        * `message_template` - Template based on recipient role and urgency.
        * `action_items` - Required actions (review_terms, approve_renewal).

### Complete Workflow Example
* **list_corpora** → Identify "contracts" corpus.
* **extract_contract_data** → Parse active contracts.
* **schedule_renewal_checks** → Identify contracts renewing in 60 days.
* **send_stakeholder_notification** → Email Contract Owner: "AWS Agreement renews March 20. Review by Feb 15."

---

## 10. Contract Clause Comparison & Analysis
[cite_start]**Goal:** Implement contract clause comparison and standardization checking[cite: 64].

### Additional Tools Needed
1.  **`extract_contract_clauses`**
    * **Purpose:** Parse and categorize specific clauses from contract documents.
    * **Functionality:**
        * Identify standard clauses (indemnification, liability, termination).
        * Parse context; handle nested clauses; normalize categorization.
        * Handle various contract formats: PDFs, Word docs.
        * Extract metadata: contract name, date, parties, jurisdiction.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "contracts").
        * `document_ids` - Specific contracts to analyze.
        * `clause_types` - Which clauses to extract (`["indemnification", "liability", "termination"]`).
        * `include_context` - Extract surrounding text for clarity.
        * `standardize_labels` - Normalize clause names across templates.

2.  **`compare_clause_variations`**
    * **Purpose:** Analyze and compare clauses across contracts to identify inconsistencies.
    * **Functionality:**
        * Compare clauses for consistency; detect non-standard terms.
        * Measure similarity scores between clauses using semantic analysis.
        * Flag high-risk variations: unlimited liability, no termination rights.
        * Compare against template/standard clauses from approved corpus.
    * **Parameters:**
        * `extracted_clauses` - Clause data from extract_contract_clauses.
        * `clause_type` - Which clause type to compare.
        * `comparison_mode` - Type of analysis (consistency_check, risk_assessment).
        * `standard_template_corpus` - Reference corpus with approved templates.
        * `risk_threshold` - Sensitivity for flagging variations.

3.  **`generate_clause_analysis_report`**
    * **Purpose:** Create comprehensive clause comparison reports with findings.
    * **Functionality:**
        * Generate detailed reports; visualize variations (heat maps).
        * Highlight non-standard terms with risk assessments.
        * Include recommendations: standardize language, negotiate changes.
        * Create summary dashboards: overall consistency score, high-risk contracts.
    * **Parameters:**
        * `comparison_results` - Analysis from compare_clause_variations.
        * `report_type` - Template (consistency_audit, risk_assessment).
        * `output_format` - Format preference (PDF, XLSX, DOCX).
        * `include_visualizations` - Chart types (variance_heatmap, risk_matrix).
        * `detail_level` - Depth (summary, detailed, clause_by_clause).
        * `sections` - Report components.

### Complete Workflow Example
* **extract_contract_clauses** → Extract indemnification clauses.
* **compare_clause_variations** → Analyze: 8 consistent, 2 unlimited liability (High Risk).
* **generate_clause_analysis_report** → Create report: "44% non-standard. Recommendation: Renegotiate XYZ Inc."

---

## 11. Legal Case Risk Assessment
[cite_start]**Goal:** Implement historical legal case analysis for risk assessment[cite: 70].

### Additional Tools Needed
1.  **`search_similar_cases`**
    * **Purpose:** Find and retrieve past legal cases similar to current situation using semantic matching.
    * **Functionality:**
        * Semantic search based on fact patterns; match by legal issues, industry.
        * Identify similar situations: contract disputes, employment claims.
        * Extract case details: parties, claims, defenses, jurisdiction, outcome.
        * Rank cases by relevance/similarity score to current situation.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "legal-cases").
        * `situation_description` - Current situation/facts to match against.
        * `similarity_factors` - What to match on (`["fact_pattern", "legal_issues", "jurisdiction"]`).
        * `filters` - Narrow search (jurisdiction, date_range).
        * `top_k` - Number of similar cases to return.

2.  **`analyze_case_outcomes`**
    * **Purpose:** Extract risk indicators and outcome patterns from historical cases.
    * **Functionality:**
        * Analyze outcomes (win rates, settlements); calculate financial risk.
        * Identify risk factors and successful defenses; detect patterns.
        * Extract winning arguments and defenses that succeeded.
        * Calculate probability metrics based on historical data.
    * **Parameters:**
        * `similar_cases` - Cases retrieved from search_similar_cases.
        * `analysis_focus` - What to analyze (`["outcome_probability", "financial_exposure"]`).
        * `current_facts` - Facts of current situation for comparison.
        * `weight_factors` - Prioritize more recent cases or same jurisdiction.
        * `risk_metrics` - Calculations to perform.

3.  **`generate_risk_assessment`**
    * **Purpose:** Create comprehensive risk analysis reports with recommendations.
    * **Functionality:**
        * Generate risk assessments; provide risk ratings (low/medium/high).
        * Include financial exposure estimates; recommend mitigation strategies.
        * Cite similar cases with outcomes as supporting evidence.
        * Support different audiences: legal team, executives, board.
    * **Parameters:**
        * `case_analysis` - Results from analyze_case_outcomes.
        * `current_situation` - Details of situation being assessed.
        * `report_type` - Template (risk_memo, executive_brief).
        * `output_format` - Format preference (PDF, DOCX).
        * `risk_dimensions` - Aspects to assess (`["financial", "reputational", "legal_precedent"]`).
        * `include_sections` - Report components.

### Complete Workflow Example
* **search_similar_cases** → Find 23 cases regarding non-competes in CA.
* **analyze_case_outcomes** → Employee won 78% of cases. Avg employer loss $125K.
* **generate_risk_assessment** → Memo: "HIGH RISK. Recommendation: Settlement strongly recommended."

---

## 12. Policy Compliance Checking
[cite_start]**Goal:** Implement automated policy validation against regulatory requirements[cite: 76].

### Additional Tools Needed
1.  **`extract_policy_requirements`**
    * **Purpose:** Parse and extract specific policy provisions from new policy documents.
    * **Functionality:**
        * Extract rules, procedures, scope; categorize elements (privacy, safety).
        * Identify policy scope: who it applies to, coverage.
        * Parse policy metadata: effective date, policy owner, version.
        * Extract measurable requirements: thresholds, timelines, approval levels.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "new-policies").
        * `document_ids` - Specific policy documents to analyze.
        * `extraction_fields` - Elements to extract (`["requirements", "scope", "procedures", "controls"]`).
        * `policy_type` - Category (data_privacy, financial, HR).
        * `include_metadata` - Extract version, owner, effective date.

2.  **`validate_against_regulations`**
    * **Purpose:** Compare policy requirements against regulatory mandates.
    * **Functionality:**
        * Map provisions to regulations; identify gaps, conflicts, and completeness.
        * Detect conflicts: policy provisions that contradict regulatory mandates.
        * Check currency: flag if regulations have been updated since policy drafting.
        * Multi-jurisdiction validation: ensure compliance across all relevant jurisdictions.
    * **Parameters:**
        * `policy_requirements` - Extracted policy data.
        * `regulations_corpus` - Corpus containing regulatory requirements.
        * `applicable_regulations` - Which regulations apply (GDPR, HIPAA, OSHA).
        * `jurisdictions` - Geographic scope (federal, state, international).
        * `validation_mode` - Type of check (gap_analysis, conflict_detection).

3.  **`generate_compliance_report`**
    * **Purpose:** Create detailed compliance validation reports with findings.
    * **Functionality:**
        * Generate reports; provide compliance scores; detail specific findings.
        * Include side-by-side comparisons: policy language vs regulatory requirement.
        * Provide remediation recommendations: specific language to add/change.
        * Include regulatory citations: reference specific regulation sections.
    * **Parameters:**
        * `validation_results` - Analysis from validate_against_regulations.
        * `policy_info` - Policy metadata and context.
        * `report_type` - Template (compliance_review, gap_analysis).
        * `output_format` - Format preference (PDF, XLSX).
        * `severity_levels` - How to categorize findings.
        * `include_sections` - Report components.

### Complete Workflow Example
* **extract_policy_requirements** → Parse Draft Privacy Policy v3.0.
* **validate_against_regulations** → Check against GDPR. Gap: "Opt-out" used instead of required "Opt-in".
* **generate_compliance_report** → "Status: REQUIRES REVISION. Critical Issue: Change consent model."

---

## 13. Customer Health Monitoring
[cite_start]**Goal:** Implement customer risk identification through support ticket and email analysis[cite: 83].

### Additional Tools Needed
1.  **`extract_sentiment_data`**
    * **Purpose:** Parse support communications and extract sentiment scores and issue details.
    * **Functionality:**
        * Analyze sentiment: positive, neutral, negative, frustrated, angry.
        * Extract issue details: problem type, severity, resolution status.
        * Identify communication patterns: response time, escalations.
        * Handle multiple communication channels: email, chat logs, tickets.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "support-tickets").
        * `customer_filter` - Specific customers or all customers.
        * `date_range` - Time period to analyze (last_30_days, last_quarter).
        * `extraction_fields` - Data to extract (`["sentiment_score", "issue_type", "resolution_time", "escalations"]`).
        * `communication_types` - Filter by channel.

2.  **`analyze_customer_risk`**
    * **Purpose:** Identify at-risk customers by analyzing sentiment trends and issue frequency.
    * **Functionality:**
        * Calculate health scores; identify risk indicators (churn signals).
        * Detect churn signals: cancellation inquiries, reduced engagement.
        * Compare to baseline; predict churn probability.
        * Measure issue severity: critical bugs, billing problems.
    * **Parameters:**
        * `sentiment_data` - Extracted data from extract_sentiment_data.
        * `risk_factors` - What to evaluate (`["sentiment_decline", "issue_frequency", "churn_signals"]`).
        * `time_window` - Period for trend analysis.
        * `risk_thresholds` - Criteria for flagging.
        * `baseline_comparison` - Compare to customer's history.

3.  **`generate_customer_alerts`**
    * **Purpose:** Create actionable customer health reports and send proactive alerts.
    * **Functionality:**
        * Generate dashboards; send real-time alerts; provide action plans.
        * Prioritize outreach: rank customers by risk level and account value.
        * Suggest interventions: executive call, product demo, service credit.
        * Track alert outcomes: which interventions worked.
    * **Parameters:**
        * `risk_analysis` - Results from analyze_customer_risk.
        * `alert_recipients` - Account owners, CSMs, support managers.
        * `urgency_level` - Priority (critical_immediate, high, medium).
        * `notification_type` - Channel (email, slack, dashboard).
        * `include_recommendations` - Action items.

### Complete Workflow Example
* **extract_sentiment_data** → Analyze Acme Corp: Sentiment -0.65, 3 escalations.
* **analyze_customer_risk** → Risk: CRITICAL. 80% churn probability.
* **generate_customer_alerts** → Email CSM: "HIGH RISK. Recommend executive escalation call within 24hrs."

---

## 14. Customized Proposal Generation
[cite_start]**Goal:** Implement automated proposal creation using relevant case studies[cite: 92].

### Additional Tools Needed
1.  **`match_case_studies`**
    * **Purpose:** Find and rank relevant case studies based on prospect characteristics.
    * **Functionality:**
        * Match by industry, company size, use case, pain points.
        * Semantic matching; score relevance.
        * Extract prospect context: goals, budget, timeline.
        * Include recency: prefer recent success stories.
    * **Parameters:**
        * `case_studies_corpus` - Corpus containing case studies.
        * `prospect_profile` - Prospect details (industry, size, goals).
        * `matching_criteria` - Factors to prioritize (`["industry", "use_case", "roi"]`).
        * `top_k` - Number of case studies to retrieve.
        * `minimum_relevance` - Threshold for inclusion.

2.  **`extract_success_metrics`**
    * **Purpose:** Parse case studies and extract compelling data points and outcomes.
    * **Functionality:**
        * Extract quantifiable results: ROI, cost savings, revenue increases.
        * Parse problem-solution-results framework.
        * Extract customer quotes and testimonials with attribution.
        * Identify technology/features used that solved specific problems.
    * **Parameters:**
        * `matched_case_studies` - Case studies from match_case_studies.
        * `extraction_focus` - What to prioritize (`["roi_metrics", "testimonials", "problem_solution"]`).
        * `metric_types` - Specific metrics (cost_reduction, efficiency_gain).
        * `include_quotes` - Extract customer testimonials.
        * `visual_elements` - Identify charts/diagrams to include.

3.  **`generate_proposal_document`**
    * **Purpose:** Create professionally formatted, customized proposals.
    * **Functionality:**
        * Generate proposals (PDF, PPT); apply branding.
        * Structure proposal sections: executive summary, solution, case studies.
        * Personalize content: use prospect name, specific pain points.
        * Integrate case studies naturally; include visualizations.
    * **Parameters:**
        * `success_metrics` - Extracted data from extract_success_metrics.
        * `prospect_info` - Prospect details for personalization.
        * `proposal_type` - Template (new_business, expansion).
        * `output_format` - Format (PDF, PPTX, DOCX).
        * `sections` - Include (`["exec_summary", "solution", "case_studies", "pricing"]`).
        * `tone` - Style (executive, technical, consultative).

### Complete Workflow Example
* **match_case_studies** → Prospect: Healthcare. Match: Memorial Hospital case (95% relevance).
* **extract_success_metrics** → Extract: "67% cost reduction", "HIPAA compliance in 45 days".
* **generate_proposal_document** → Create proposal featuring Memorial Hospital success story.

---

## 15. Competitive Intelligence & Positioning
[cite_start]**Goal:** Implement competitor analysis and competitive positioning report generation[cite: 99].

### Additional Tools Needed
1.  **`extract_competitive_data`**
    * **Purpose:** Parse competitor analysis documents and extract structured intelligence.
    * **Functionality:**
        * Extract info (products, pricing, strengths); parse matrices.
        * Capture messaging and roadmap; handle multiple formats.
        * Extract market data: market share, growth rates.
        * Parse win/loss analysis: reasons won/lost against competitors.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "competitive-analysis").
        * `competitor_filter` - Specific competitors or all.
        * `extraction_fields` - Data to extract (`["features", "pricing", "strengths", "market_position"]`).
        * `include_sources` - Track source documents.
        * `time_relevance` - Prioritize recent intelligence.

2.  **`analyze_competitive_position`**
    * **Purpose:** Compare company capabilities against competitors to identify advantages/gaps.
    * **Functionality:**
        * Generate comparison matrices; identify advantages/gaps.
        * Calculate scores; analyze pricing; perform SWOT.
        * Analyze pricing positioning: premium, competitive, value.
        * Generate win themes: strongest arguments against each competitor.
    * **Parameters:**
        * `competitive_data` - Extracted data from extract_competitive_data.
        * `company_data_corpus` - Internal corpus with product info.
        * `comparison_dimensions` - What to analyze (`["features", "pricing", "support"]`).
        * `competitors_to_compare` - Which competitors to include.
        * `analysis_type` - Focus (`["swot", "win_themes", "gap_analysis"]`).

3.  **`generate_positioning_report`**
    * **Purpose:** Create comprehensive competitive positioning reports and sales enablement materials.
    * **Functionality:**
        * Generate reports (battle cards, summaries); create comparison charts.
        * Create sales battle cards: how to compete against each competitor.
        * Generate talking points and objection handling.
        * Track competitive positioning over time.
    * **Parameters:**
        * `positioning_analysis` - Results from analyze_competitive_position.
        * `report_type` - Template (battle_card, executive_overview).
        * `output_format` - Format (PDF, PPTX).
        * `competitor_focus` - Specific head-to-head matchup.
        * `include_sections` - Components (`["executive_summary", "feature_matrix", "win_themes", "objection_handling"]`).

### Complete Workflow Example
* **extract_competitive_data** → Competitor A: $99/mo, weak SMB support.
* **analyze_competitive_position** → Advantage: Our pricing $89/mo + better support. Win Theme: "Better value."
* **generate_positioning_report** → Create Sales Battle Card: "How to beat Competitor A."

---

## 16. Renewal Prediction Analysis
[cite_start]**Goal:** Implement predictive renewal analysis based on historical patterns[cite: 106].

### Additional Tools Needed
1.  **`extract_renewal_history`**
    * **Purpose:** Parse and extract historical customer renewal data and patterns.
    * **Functionality:**
        * Extract renewal records; parse lifecycle data.
        * Identify timing and outcomes; track leading indicators.
        * Extract contextual factors: pricing changes, product usage, support interactions.
        * Track outcomes: upsell, churn, downgrade.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "sales-history").
        * `date_range` - Historical period to analyze.
        * `extraction_fields` - Data to extract (`["renewal_outcome", "contract_value", "tenure", "churn_reasons"]`).
        * `customer_segment` - Filter by segment.
        * `include_context` - Extract supporting factors.

2.  **`identify_renewal_patterns`**
    * **Purpose:** Analyze historical data to identify predictive factors and renewal likelihood.
    * **Functionality:**
        * Identify predictors; build cohort analysis; detect warning signals.
        * Calculate renewal probability scores based on historical patterns.
        * Identify risk factors: pricing sensitivity, competitive losses.
        * Segment customers by renewal likelihood.
    * **Parameters:**
        * `renewal_history` - Historical data from extract_renewal_history.
        * `analysis_type` - Focus (predictive_factors, risk_scoring).
        * `prediction_horizon` - How far ahead to predict.
        * `include_factors` - Which variables to analyze (`["usage", "engagement", "support"]`).
        * `model_type` - Approach (statistical, machine_learning).

3.  **`generate_renewal_forecast`**
    * **Purpose:** Create actionable renewal predictions and intervention recommendations.
    * **Functionality:**
        * Generate forecast reports; score customers.
        * Prioritize by impact; provide intervention recommendations.
        * Create customer-specific playbooks: tailored retention strategies.
        * Generate timeline views: renewal pipeline by month/quarter.
    * **Parameters:**
        * `pattern_analysis` - Results from identify_renewal_patterns.
        * `upcoming_renewals` - Customers with renewals in prediction window.
        * `report_type` - Template (forecast, action_plan).
        * `output_format` - Format (PDF, dashboard, CSV).
        * `priority_ranking` - How to rank (renewal_risk, account_value).

### Complete Workflow Example
* **extract_renewal_history** → Parse 450 records. 75% renewal rate.
* **identify_renewal_patterns** → Low usage (<30%) correlates with 72% churn risk.
* **generate_renewal_forecast** → "Acme Inc: High Risk (28%). Action: Executive call needed."

---

## 17. Project Status Monitoring
[cite_start]**Goal:** Implement project monitoring with automated alerts for missed milestones and budget overruns[cite: 113].

### Additional Tools Needed
1.  **`extract_project_data`**
    * **Purpose:** Parse project documents and extract structured info, timelines, and budgets.
    * **Functionality:**
        * Extract metadata, milestones, budget data; identify phases.
        * Parse resource allocation and risks.
        * Handle multiple document formats: project plans, status reports.
        * Track historical updates: compare current status to previous reports.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "project-docs").
        * `project_filter` - Specific projects or all active projects.
        * `extraction_fields` - Data to extract (`["milestones", "budget", "status", "risks"]`).
        * `date_range` - Period to analyze.
        * `include_history` - Track changes over time.

2.  **`monitor_project_health`**
    * **Purpose:** Analyze project data to detect risks (missed milestones, overruns).
    * **Functionality:**
        * Track progress; monitor budget variance; detect slippage.
        * Calculate health scores; identify risk patterns.
        * Compare to baseline: original plan vs current reality.
        * Generate prioritized issue list: critical problems requiring attention.
    * **Parameters:**
        * `project_data` - Extracted data from extract_project_data.
        * `monitoring_rules` - What to check (`["milestone_delays", "budget_overruns"]`).
        * `alert_thresholds` - When to flag issues.
        * `current_date` - Reference date.
        * `risk_scoring` - How to calculate project health.

3.  **`send_project_alerts`**
    * **Purpose:** Send targeted notifications to stakeholders when issues are detected.
    * **Functionality:**
        * Send alerts via multiple channels; route to appropriate roles.
        * Customize by severity; include actionable context.
        * Generate escalation paths: notify higher levels for critical issues.
        * Include visualizations: timeline views, budget charts.
    * **Parameters:**
        * `alert_recipients` - Stakeholders (project_manager, sponsor).
        * `project_issues` - Problems detected.
        * `urgency_level` - Priority (critical, high, medium).
        * `notification_type` - Channel (email, slack, dashboard).
        * `message_template` - Template based on issue type.

### Complete Workflow Example
* **extract_project_data** → Project Atlas: Budget $750K, Spent $810K.
* **monitor_project_health** → Status: CRITICAL. Over budget by 8%.
* **send_project_alerts** → Email PM: "CRITICAL: Project Atlas over budget. Immediate review required."

---

## 18. SLA Compliance Monitoring & Scorecard Generation
[cite_start]**Goal:** Implement vendor SLA compliance analysis and quarterly performance reporting[cite: 122].

### Additional Tools Needed
1.  **`extract_sla_metrics`**
    * **Purpose:** Parse vendor contracts and performance data to extract SLA commitments and actuals.
    * **Functionality:**
        * Extract commitments (uptime, response); parse performance data.
        * Identify thresholds; extract penalty terms.
        * Normalize across vendors: standardize metric names.
        * Track time periods: monthly, quarterly, annual.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "vendor-contracts").
        * `vendor_filter` - Specific vendors or all.
        * `extraction_fields` - Data to extract (`["sla_commitments", "actual_performance", "penalty_terms"]`).
        * `time_period` - Performance window.
        * `metric_types` - Which SLAs to track (uptime, response_time).

2.  **`calculate_sla_compliance`**
    * **Purpose:** Compare actual performance against SLA commitments and calculate scores.
    * **Functionality:**
        * Calculate compliance percentages; identify breaches.
        * Compute service credits; track trends.
        * Aggregate metrics: overall vendor score.
        * Generate compliance grades: A/B/C/D ratings.
    * **Parameters:**
        * `sla_metrics` - Extracted data from extract_sla_metrics.
        * `calculation_type` - Analysis focus (compliance_percentage, breach_detection).
        * `time_period` - Period to analyze.
        * `aggregation_level` - Detail (by_vendor, by_service).
        * `scoring_method` - How to grade.

3.  **`generate_performance_scorecard`**
    * **Purpose:** Create comprehensive vendor performance reports with scorecards.
    * **Functionality:**
        * Generate scorecards; visualize compliance; rank vendors.
        * Highlight breaches; calculate financial impact.
        * Provide executive summaries: high-level insights.
        * Generate action items: vendors requiring attention.
    * **Parameters:**
        * `compliance_analysis` - Results from calculate_sla_compliance.
        * `report_type` - Template (scorecard, vendor_comparison).
        * `output_format` - Format (PDF, PPTX).
        * `time_period` - Reporting period.
        * `include_visualizations` - Chart types.

### Complete Workflow Example
* **extract_sla_metrics** → CloudHost: Committed 99.9%, Actual 99.87%.
* **calculate_sla_compliance** → BREACH. $5,000 credit owed. Grade B.
* **generate_performance_scorecard** → Generate Q4 Scorecard with breach details and credit calculation.

---

## 19. Incident Pattern Analysis & Root Cause Investigation
[cite_start]**Goal:** Implement recurring issue identification and root cause investigation recommendations[cite: 129].

### Additional Tools Needed
1.  **`extract_incident_data`**
    * **Purpose:** Parse incident reports and extract structured information for pattern analysis.
    * **Functionality:**
        * Extract incident details, timeline, symptoms, resolution.
        * Categorize incidents; normalize descriptions.
        * Handle multiple formats: ticketing systems, incident logs.
        * Extract environmental factors: time of day, system load.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "incident-logs").
        * `date_range` - Time period to analyze.
        * `extraction_fields` - Data to extract (`["symptoms", "resolution_actions", "severity"]`).
        * `severity_filter` - Focus on specific severities.
        * `incident_types` - Filter by type.

2.  **`identify_recurring_patterns`**
    * **Purpose:** Analyze incidents to detect patterns and systemic issues.
    * **Functionality:**
        * Cluster similar incidents; identify frequency and temporal patterns.
        * Track chains; calculate MTBF.
        * Identify trigger events: deployments, changes.
        * Measure impact severity: customer impact prioritization.
    * **Parameters:**
        * `incident_data` - Extracted data from extract_incident_data.
        * `analysis_type` - Focus (frequency_analysis, symptom_clustering).
        * `similarity_threshold` - How closely incidents must match.
        * `time_grouping` - Look for patterns by hour/day.
        * `minimum_occurrences` - Threshold to flag as recurring.

3.  **`generate_rca_recommendations`**
    * **Purpose:** Create root cause investigation plans and remediation recommendations.
    * **Functionality:**
        * Generate RCA reports; provide investigation guidance.
        * Recommend teams; suggest preventive measures.
        * Create hypothesis lists: likely root causes.
        * Prioritize investigations: based on ROI/impact.
    * **Parameters:**
        * `pattern_analysis` - Results from identify_recurring_patterns.
        * `report_type` - Template (rca_plan, executive_summary).
        * `output_format` - Format (PDF, Jira_tickets).
        * `priority_ranking` - How to prioritize.
        * `include_sections` - Components (`["investigation_plan", "recommended_actions"]`).

### Complete Workflow Example
* **extract_incident_data** → Parse 234 database timeout incidents.
* **identify_recurring_patterns** → Pattern: Occurs 9-11am EST (peak traffic).
* **generate_rca_recommendations** → Plan: "Investigate connection pool size. Recommended Team: DB Admin."

---

## 20. Resource Capacity Planning
[cite_start]**Goal:** Implement predictive resource planning based on historical utilization data[cite: 137].

### Additional Tools Needed
1.  **`extract_utilization_metrics`**
    * **Purpose:** Parse historical resource utilization data and extract time-series metrics.
    * **Functionality:**
        * Extract utilization data (CPU, storage, headcount); parse temporal data.
        * Identify resource types: compute, storage, personnel, licenses.
        * Parse cost data: resource costs over time.
        * Normalize across systems: standardize metrics.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "capacity-reports").
        * `date_range` - Historical period to analyze.
        * `resource_types` - What to analyze (`["infrastructure", "personnel", "storage"]`).
        * `extraction_fields` - Metrics to extract (`["usage_percentage", "peak_loads", "growth_rates"]`).
        * `granularity` - Time resolution (hourly, daily).

2.  **`analyze_utilization_trends`**
    * **Purpose:** Analyze patterns and predict future requirements.
    * **Functionality:**
        * Calculate growth rates; identify patterns; project future demand.
        * Predict saturation points; model scenarios.
        * Calculate resource efficiency: utilization rates, waste identification.
        * Compare actual vs predicted: validate forecasting accuracy.
    * **Parameters:**
        * `utilization_data` - Historical metrics from extract_utilization_metrics.
        * `analysis_type` - Focus (growth_trends, capacity_forecast).
        * `prediction_horizon` - How far ahead to forecast.
        * `business_factors` - Consider (`["user_growth", "product_launches"]`).
        * `modeling_approach` - Technique (trend_line, machine_learning).

3.  **`generate_capacity_plan`**
    * **Purpose:** Create actionable capacity plans with budget projections.
    * **Functionality:**
        * Generate reports; provide forecasts; calculate budgets.
        * Identify optimization opportunities: underutilized resources.
        * Provide procurement guidance: lead times, vendor options.
        * Create scenario comparisons: cost-benefit analysis.
    * **Parameters:**
        * `trend_analysis` - Results from analyze_utilization_trends.
        * `report_type` - Template (capacity_forecast, procurement_plan).
        * `output_format` - Format (PDF, XLSX).
        * `planning_horizon` - Period covered.
        * `include_sections` - Components (`["executive_summary", "capacity_recommendations", "budget_impact"]`).

### Complete Workflow Example
* **extract_utilization_metrics** → Storage usage growing 12% per quarter.
* **analyze_utilization_trends** → Forecast: Capacity exhausted in 3 months.
* **generate_capacity_plan** → "Immediate Action: Add 5TB storage ($15K)."

---

## 21. Documentation Gap Analysis
[cite_start]**Goal:** Implement FAQ identification and documentation gap detection[cite: 145].

### Additional Tools Needed
1.  **`extract_questions_data`**
    * **Purpose:** Parse support channels and extract FAQs with context.
    * **Functionality:**
        * Extract questions; identify patterns; parse context.
        * Categorize questions: features, troubleshooting, how-to.
        * Track question frequency: count occurrences, trending topics.
        * Identify question difficulty: resolution time, escalations.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "support-tickets").
        * `date_range` - Time period to analyze.
        * `extraction_fields` - Data to extract (`["question_text", "category", "frequency"]`).
        * `question_types` - Filter by type.
        * `minimum_occurrences` - Threshold for frequency.

2.  **`match_to_documentation`**
    * **Purpose:** Check if questions are answered in existing documentation.
    * **Functionality:**
        * Search docs for answers; assess quality; identify gaps.
        * Categorize gaps by severity: critical gaps vs minor gaps.
        * Identify ambiguous documentation: questions arising from unclear docs.
        * Track question-to-documentation mapping.
    * **Parameters:**
        * `questions_data` - Extracted questions from extract_questions_data.
        * `documentation_corpus` - Corpus with existing documentation.
        * `matching_threshold` - How closely documentation must match.
        * `gap_severity` - Classification based on frequency/importance.
        * `assessment_criteria` - What constitutes adequate documentation.

3.  **`generate_documentation_roadmap`**
    * **Purpose:** Create prioritized documentation gap reports and content plans.
    * **Functionality:**
        * Generate gap reports; prioritize needs; provide content recommendations.
        * Create documentation briefs: question clusters, required info.
        * Estimate effort: documentation complexity, research needed.
        * Generate content templates: structured outlines.
    * **Parameters:**
        * `gap_analysis` - Results from match_to_documentation.
        * `report_type` - Template (gap_report, content_roadmap).
        * `output_format` - Format (PDF, confluence_page).
        * `priority_ranking` - How to prioritize.
        * `include_sections` - Components (`["prioritized_roadmap", "content_briefs", "roi_estimates"]`).

### Complete Workflow Example
* **extract_questions_data** → "Salesforce Integration" asked 89 times.
* **match_to_documentation** → Result: No documentation found (Critical Gap).
* **generate_documentation_roadmap** → Priority 1: Create Salesforce Integration Guide.

---

## 22. Release Notes Comparison & "What's New" Generation
[cite_start]**Goal:** Implement automated "what's new" summary generation by comparing release versions[cite: 156].

### Additional Tools Needed
1.  **`extract_release_data`**
    * **Purpose:** Parse release notes and extract structured version info.
    * **Functionality:**
        * Extract version metadata, change categories, technical details.
        * Parse change categories: new features, bug fixes, breaking changes.
        * Handle multiple formats: Markdown, HTML, CHANGELOG files.
        * Normalize across versions: standardize categorization.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "release-notes").
        * `version_range` - Versions to compare.
        * `extraction_fields` - Data to extract (`["features", "bug_fixes", "breaking_changes"]`).
        * `include_metadata` - Version numbers, dates, release type.
        * `change_granularity` - Detail level.

2.  **`compare_versions`**
    * **Purpose:** Analyze differences between versions and categorize changes.
    * **Functionality:**
        * Identify additions/removals; categorize by impact.
        * Compare feature maturity: beta to stable.
        * Assess upgrade complexity: simple update vs migration required.
        * Calculate change magnitude: number of changes, API surface changes.
    * **Parameters:**
        * `release_data` - Extracted data from extract_release_data.
        * `current_version` - Version being released.
        * `comparison_versions` - Previous versions to compare against.
        * `comparison_focus` - What to emphasize (`["user_facing_changes", "breaking_changes"]`).
        * `impact_assessment` - Categorize by severity.

3.  **`generate_whats_new_summary`**
    * **Purpose:** Create compelling "what's new" content for different audiences.
    * **Functionality:**
        * Generate summaries (blog, email); create audience-specific versions.
        * Write compelling narratives: emphasize benefits.
        * Include visual comparisons: before/after screenshots.
        * Provide upgrade guidance: steps to update.
    * **Parameters:**
        * `version_comparison` - Analysis from compare_versions.
        * `content_type` - Format (blog_post, email, release_notes).
        * `target_audience` - Who's reading (end_users, developers).
        * `tone` - Style (marketing, technical).
        * `include_sections` - Components (`["key_highlights", "detailed_changes", "upgrade_guide"]`).

### Complete Workflow Example
* **extract_release_data** → Parse v2.5 vs v2.4.
* **compare_versions** → Major new feature: Real-time collaboration. Breaking change: API v1.
* **generate_whats_new_summary** → Blog post: "What's New in v2.5: Collaboration Meets Performance."

---

## 23. Expert Routing Based on Knowledge Contributions
[cite_start]**Goal:** Implement intelligent expert routing based on knowledge base contributions[cite: 170].

### Additional Tools Needed
1.  **`extract_expertise_profiles`**
    * **Purpose:** Analyze contributions to build expert profiles.
    * **Functionality:**
        * Extract authorship data; identify expertise areas.
        * Quantify expertise depth: number of contributions, quality indicators.
        * Build expertise graphs: relationships between experts.
        * Handle multiple sources: docs, forums, code.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "technical-docs").
        * `contributor_filter` - Specific people or all.
        * `extraction_fields` - Data to extract (`["topics", "contribution_count", "expertise_depth"]`).
        * `time_relevance` - Weight recent contributions.
        * `expertise_dimensions` - What defines expertise.

2.  **`match_question_to_expert`**
    * **Purpose:** Analyze questions and match to qualified experts.
    * **Functionality:**
        * Parse question content; match to profiles.
        * Rank experts by relevance; check availability.
        * Consider context factors: urgency, customer importance.
        * Apply routing rules: load balancing, specialty matching.
    * **Parameters:**
        * `question_data` - Incoming question details.
        * `expertise_profiles` - Expert data from extract_expertise_profiles.
        * `matching_criteria` - Factors to consider (`["topic_match", "availability"]`).
        * `routing_strategy` - Approach (best_match, round_robin).
        * `consider_workload` - Balance expertise with capacity.

3.  **`route_and_notify_expert`**
    * **Purpose:** Assign questions to experts and send notifications.
    * **Functionality:**
        * Route via channels; provide context.
        * Include expertise justification: why selected.
        * Track assignment: log routing decisions.
        * Enable expert actions: accept, reassign, escalate.
    * **Parameters:**
        * `matched_expert` - Selected expert.
        * `question_details` - Full question context.
        * `notification_type` - Channel (email, slack).
        * `urgency_level` - Priority.
        * `include_context` - What to provide (similar_questions, requester_profile).

### Complete Workflow Example
* **match_question_to_expert** → Question about FastAPI. Match: Sarah Chen (95% expertise).
* **route_and_notify_expert** → Slack to Sarah: "New High Priority Question. Why you: You wrote the FastAPI guide."

---

## 24. Standards & Best Practices Verification
[cite_start]**Goal:** Implement internal procedure verification against industry standards[cite: 179].

### Additional Tools Needed
1.  **`extract_procedure_data`**
    * **Purpose:** Parse procedures and extract structured requirements.
    * **Functionality:**
        * Extract steps, scope, controls; categorize procedures.
        * Identify procedure scope: departments, systems covered.
        * Extract measurable criteria: performance metrics.
        * Parse metadata: owner, version, approval status.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "internal-procedures").
        * `procedure_filter` - Specific procedures to analyze.
        * `extraction_fields` - Data to extract (`["requirements", "controls", "compliance_elements"]`).
        * `procedure_categories` - Filter by type.
        * `include_metadata` - Version, owner, status.

2.  **`compare_to_standards`**
    * **Purpose:** Compare procedures against industry standards (ISO, SOC2).
    * **Functionality:**
        * Match to standards; identify gaps/conflicts.
        * Assess maturity level: ad-hoc vs optimized.
        * Evaluate control effectiveness.
        * Track standard updates.
    * **Parameters:**
        * `procedure_data` - Extracted data from extract_procedure_data.
        * `standards_corpus` - Corpus containing industry standards.
        * `applicable_standards` - Which standards apply (ISO_27001, SOC2).
        * `comparison_type` - Focus (gap_analysis, compliance_check).
        * `assessment_criteria` - How to evaluate.

3.  **`generate_alignment_report`**
    * **Purpose:** Create alignment reports with gaps and recommendations.
    * **Functionality:**
        * Generate reports; provide compliance scores.
        * Detail specific gaps: severity, risk level.
        * Provide improvement roadmap: prioritized actions.
        * Generate audit-ready documentation.
    * **Parameters:**
        * `comparison_results` - Analysis from compare_to_standards.
        * `report_type` - Template (compliance_assessment, gap_analysis).
        * `output_format` - Format (PDF, XLSX).
        * `standards_focus` - Which standards to highlight.
        * `include_sections` - Components (`["executive_summary", "gap_analysis", "remediation_plan"]`).

### Complete Workflow Example
* **compare_to_standards** → Check against ISO 27001. Gap: No documented Privileged Access Management.
* **generate_alignment_report** → "Alignment 78%. Critical Gap: Implement PAM within 30 days."

---

## 25. Treatment Protocol Contraindication Alerts
[cite_start]**Goal:** Implement treatment protocol verification and contraindication alerting[cite: 187].

### Additional Tools Needed
1.  **`extract_patient_data`**
    * **Purpose:** Parse records and extract clinical info for checking.
    * **Functionality:**
        * Extract history, meds, labs; normalize terminology.
        * Identify patient characteristics: age, weight, pregnancy status.
        * Extract temporal data: when conditions diagnosed.
        * Ensure data privacy: HIPAA-compliant extraction.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "patient-records").
        * `patient_id` - Specific patient identifier.
        * `extraction_fields` - Data to extract (`["diagnoses", "medications", "allergies", "lab_results"]`).
        * `time_range` - Historical period.
        * `include_sensitive` - Whether to include sensitive data types.

2.  **`check_contraindications`**
    * **Purpose:** Analyze protocols against patient data for risks.
    * **Functionality:**
        * Check drug-drug/drug-disease interactions.
        * Detect allergy conflicts.
        * Assess dosage appropriateness (age, kidney function).
        * Reference clinical guidelines.
    * **Parameters:**
        * `patient_data` - Clinical data from extract_patient_data.
        * `proposed_treatment` - Treatment protocol being considered.
        * `treatment_corpus` - Corpus with protocols/drug info.
        * `contraindication_types` - What to check (`["drug_interactions", "allergies", "lab_values"]`).
        * `severity_threshold` - Alert level.

3.  **`alert_healthcare_provider`**
    * **Purpose:** Send urgent notifications with clinical context.
    * **Functionality:**
        * Send real-time alerts; provide evidence and alternatives.
        * Show severity levels: critical vs warning.
        * Enable provider response: acknowledge, override.
        * Document alert: log for legal/quality records.
    * **Parameters:**
        * `alert_recipients` - Providers (physician, pharmacist).
        * `contraindication_details` - Issues detected.
        * `urgency_level` - Priority.
        * `notification_type` - Channel (ehr_popup, page).
        * `include_context` - Information to provide (patient_summary, evidence).

### Complete Workflow Example
* **check_contraindications** → Order: Ibuprofen. Patient on Warfarin + CKD.
* **alert_healthcare_provider** → "CRITICAL: Drug-Drug Interaction (Bleeding risk) & Drug-Disease (Kidney injury). Order Blocked."

---

## 26. Systematic Review Compilation
[cite_start]**Goal:** Implement automated systematic review generation from research papers[cite: 197].

### Additional Tools Needed
1.  **`extract_research_data`**
    * **Purpose:** Parse papers and extract structured study info.
    * **Functionality:**
        * Extract metadata, design, population, results.
        * Identify study quality indicators: blinding, randomization.
        * Handle multiple formats: PDF papers, abstracts.
        * Normalize terminology using MeSH terms.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "research-papers").
        * `topic_filter` - Topic being reviewed.
        * `extraction_fields` - Data to extract (`["study_design", "population", "results", "quality_metrics"]`).
        * `study_types` - Filter by type (rct, cohort).
        * `quality_assessment` - Apply quality scoring (GRADE).

2.  **`synthesize_evidence`**
    * **Purpose:** Analyze multiple studies to identify patterns and consensus.
    * **Functionality:**
        * Aggregate findings; identify consensus/conflicts.
        * Calculate meta-statistics: pooled effect sizes.
        * Assess evidence quality: GRADE methodology.
        * Identify publication bias.
    * **Parameters:**
        * `research_data` - Extracted data from extract_research_data.
        * `synthesis_type` - Analysis approach (meta_analysis, narrative).
        * `statistical_methods` - Calculations to perform.
        * `quality_framework` - Assessment tool (GRADE, Cochrane).
        * `subgroup_analysis` - Break down by population/dosage.

3.  **`generate_systematic_review`**
    * **Purpose:** Create publication-ready systematic reviews.
    * **Functionality:**
        * Generate PRISMA-compliant reviews.
        * Create flowcharts/forest plots.
        * Write synthesis narratives.
        * Generate recommendations based on evidence.
    * **Parameters:**
        * `evidence_synthesis` - Analysis from synthesize_evidence.
        * `review_type` - Format (full_review, guideline).
        * `output_format` - Format (manuscript_PDF, report).
        * `target_journal` - Format for specific requirements.
        * `include_sections` - Components (`["methods", "results", "prisma_diagram", "forest_plots"]`).

### Complete Workflow Example
* **extract_research_data** → Parse 15 RCTs on Metformin/Prediabetes.
* **synthesize_evidence** → Pooled result: 31% risk reduction. Quality: Moderate.
* **generate_systematic_review** → Generate manuscript with PRISMA diagram and Forest Plot.

---

## 27. Clinical Trial Matching
[cite_start]**Goal:** Implement patient-to-clinical-trial matching based on eligibility[cite: 212].

### Additional Tools Needed
1.  **`extract_trial_criteria`**
    * **Purpose:** Parse protocols and extract eligibility criteria.
    * **Functionality:**
        * Extract inclusion/exclusion criteria; handle complex logic.
        * Identify specific requirements: measurable disease, organ function.
        * Normalize medical terminology.
        * Parse geographic restrictions.
    * **Parameters:**
        * `corpus_name` - Source corpus (e.g., "clinical-trials").
        * `trial_filter` - Specific trials or all active.
        * `extraction_fields` - Data to extract (`["inclusion_criteria", "exclusion_criteria", "locations"]`).
        * `trial_status` - Filter by status (recruiting).
        * `disease_area` - Focus on specific conditions.

2.  **`match_patient_to_trials`**
    * **Purpose:** Compare patient profile against criteria to find matches.
    * **Functionality:**
        * Evaluate criteria; match labs/diagnoses.
        * Check medication conflicts.
        * Calculate match confidence: full vs partial.
        * Prioritize trials: rank by quality, proximity.
    * **Parameters:**
        * `patient_profile` - Clinical data from extract_patient_data.
        * `trial_criteria` - Extracted criteria from extract_trial_criteria.
        * `matching_strictness` - Approach (exact_match, potential).
        * `distance_limit` - Geographic restriction.
        * `trial_phases` - Phases to consider.

3.  **`generate_trial_recommendations`**
    * **Purpose:** Create personalized trial recommendations.
    * **Functionality:**
        * Generate reports; rank trials; explain eligibility.
        * Provide enrollment instructions.
        * Identify near-misses.
        * Support shared decision-making.
    * **Parameters:**
        * `match_results` - Results from match_patient_to_trials.
        * `report_type` - Format (patient_facing, physician_referral).
        * `output_format` - Format (PDF, secure_message).
        * `number_of_trials` - How many to recommend.
        * `include_sections` - Components (`["trial_summaries", "enrollment_steps"]`).

### Complete Workflow Example
* **match_patient_to_trials** → Patient: HER2+ Breast Cancer. Match: NCT05234567 (100% Eligible).
* **generate_trial_recommendations** → Report: "Highly Recommended: Novel ADC Trial at UCSD."

---

## 28. Drug Interaction Checking
[cite_start]**Goal:** Implement prescription verification against known drug interactions[cite: 223].

### Additional Tools Needed
1.  **`extract_prescription_data`**
    * **Purpose:** Parse new orders and extract medication info.
    * **Functionality:**
        * Extract drug, dosage, context; normalize names.
        * Identify drug class; parse prescription context.
        * Handle multiple formats: e-prescribing, orders.
    * **Parameters:**
        * `prescription_source` - Where prescription originates.
        * `prescription_data` - Raw prescription info.
        * `extraction_fields` - Data to extract (`["drug_name", "dosage", "frequency"]`).
        * `normalize_names` - Standardize to generic.
        * `include_context` - Patient ID, prescriber.

2.  **`check_drug_interactions`**
    * **Purpose:** Query database to identify interactions.
    * **Functionality:**
        * Identify types/mechanisms; assess severity.
        * Check multi-drug interactions.
        * Evaluate clinical significance.
        * Check food/supplement interactions.
    * **Parameters:**
        * `new_prescription` - Medication being added.
        * `current_medications` - Patient's existing list.
        * `interaction_corpus` - Database of interactions.
        * `severity_threshold` - Alert level.
        * `patient_factors` - Consider age, comorbidities.

3.  **`generate_interaction_alert`**
    * **Purpose:** Create actionable alerts with clinical recommendations.
    * **Functionality:**
        * Generate real-time alerts; provide severity-based presentation.
        * Suggest alternatives; provide management strategies.
        * Enable prescriber response; document decisions.
    * **Parameters:**
        * `interaction_findings` - Detected interactions.
        * `alert_recipients` - Who to notify.
        * `urgency_level` - Severity.
        * `notification_type` - Channel.
        * `include_recommendations` - Alternatives, strategies.

### Complete Workflow Example
* **check_drug_interactions** → Clarithromycin + Simvastatin. Result: CONTRAINDICATED (Rhabdomyolysis risk).
* **generate_interaction_alert** → Alert: "CRITICAL: Order Blocked. Risk of muscle breakdown. Alternatives: Doxycycline."