# EventBridge Secure Module (No hardcoded values)

## What makes this secure
- **No hardcoded ARNs required**: you can pass Lambda **function names** (or store them in **SSM Parameter Store**) and the module resolves ARNs dynamically.
- **Least privilege**: Lambda permission is scoped per-rule via `source_arn`.
- **Controlled payload**: Use `input_transformer` to pass only what's needed (avoid leaking PII to targets).
- **Reliability**: Optional DLQ + retry policy per target.
- **No secrets in repo**: tfvars are optional; you can drive values from SSM. Add `*.tfvars` to `.gitignore`.

## Using SSM instead of hardcoding
```bash
aws ssm put-parameter --name "/dev/lambda/orders_processor_name" \
  --value "myLambda" --type String --overwrite --region us-east-1
```

Then in Terraform we read the name and resolve the ARN automatically.

## Send a manual test event (Windows-friendly)
Create `entries.json` and run:
```powershell
aws events put-events --region us-east-1 --entries file://entries.json
```

## Optional: strict event bus policy (cross-account)
Pass `bus_policy_json` with a **minimal** policy that whitelists only required principals and uses `Condition` keys like `aws:SourceAccount` and `aws:SourceArn`.
