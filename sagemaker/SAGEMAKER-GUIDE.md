# SageMaker Notebook Quick Start Guide

## Step-by-Step: Create Your Notebook

### Step 1: Deploy the Infrastructure (5 minutes)

```bash
cd /home/anon/Documents/code/terraform

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create the SageMaker notebook
terraform apply
# Type 'yes' when prompted
```

**What gets created:**
- ✓ SageMaker notebook instance (ml.t3.medium)
- ✓ S3 bucket for your data
- ✓ IAM roles with proper permissions
- ✓ Pre-installed ML packages (pandas, numpy, scikit-learn, etc.)

---

### Step 2: Wait for Notebook to Start (2-3 minutes)

```bash
# Check notebook status
aws sagemaker describe-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart \
  --query 'NotebookInstanceStatus' \
  --output text

# Wait for status to be "InService"
# You'll see: Pending → InService
```

Or use this one-liner to wait:
```bash
while true; do
  status=$(aws sagemaker describe-notebook-instance --notebook-instance-name ml-notebook-quickstart --query 'NotebookInstanceStatus' --output text)
  echo "Status: $status"
  [[ "$status" == "InService" ]] && break
  sleep 10
done
echo "Notebook is ready!"
```

---

### Step 3: Access Your Notebook

**Option 1: AWS Console (Easiest)**
```bash
# Get the direct link
terraform output aws_console_url

# This will show something like:
# https://console.aws.amazon.com/sagemaker/home?region=us-east-1#/notebook-instances/ml-notebook-quickstart
```

1. Copy that URL and paste in your browser
2. Click **"Open JupyterLab"** button
3. You're in!

**Option 2: Command Line**
```bash
# Get presigned URL (valid for 5 minutes)
aws sagemaker create-presigned-notebook-instance-url \
  --notebook-instance-name ml-notebook-quickstart \
  --query 'AuthorizedUrl' \
  --output text

# Copy the URL and open in browser
```

---

## Simple Code to Run in Your Notebook

Once you're in JupyterLab:

### Example 1: Hello World (Test Everything Works)

Click **File → New → Notebook**, select **conda_python3**, then run:

```python
# Cell 1: Basic Python
print("Hello from SageMaker!")
print(f"Python is working! ✓")

import sys
print(f"Python version: {sys.version}")
```

```python
# Cell 2: Check installed packages
import pandas as pd
import numpy as np
import sklearn
import boto3

print(f"pandas: {pd.__version__} ✓")
print(f"numpy: {np.__version__} ✓")
print(f"scikit-learn: {sklearn.__version__} ✓")
print(f"boto3: {boto3.__version__} ✓")
print("\nAll packages working!")
```

---

### Example 2: Work with Your S3 Bucket

```python
# Cell 1: Connect to S3
import boto3
import pandas as pd

# Get your bucket name (from Terraform output)
s3 = boto3.client('s3')

# Replace with your bucket name from 'terraform output'
BUCKET_NAME = 'sagemaker-notebook-data-XXXXXXXX'  # Get from terraform output

# List bucket contents
response = s3.list_objects_v2(Bucket=BUCKET_NAME)
print(f"Bucket '{BUCKET_NAME}' is accessible! ✓")
```

```python
# Cell 2: Create sample data and upload to S3
import pandas as pd
import io

# Create sample dataset
data = pd.DataFrame({
    'name': ['Alice', 'Bob', 'Charlie', 'Diana'],
    'age': [25, 30, 35, 28],
    'score': [92.5, 88.0, 95.5, 91.0]
})

print("Sample data:")
print(data)

# Save to S3
csv_buffer = io.StringIO()
data.to_csv(csv_buffer, index=False)

s3.put_object(
    Bucket=BUCKET_NAME,
    Key='data/sample.csv',
    Body=csv_buffer.getvalue()
)

print("\n✓ Data uploaded to S3!")
```

```python
# Cell 3: Read data from S3
# Read the CSV back from S3
obj = s3.get_object(Bucket=BUCKET_NAME, Key='data/sample.csv')
df = pd.read_csv(obj['Body'])

print("Data read from S3:")
print(df)
print(f"\n✓ Successfully read {len(df)} rows from S3!")
```

---

### Example 3: Simple Machine Learning

```python
# Cell 1: Create sample ML dataset
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score
import matplotlib.pyplot as plt

# Generate sample data: house prices based on size
np.random.seed(42)
house_sizes = np.random.randint(800, 3500, 100)  # Square feet
house_prices = house_sizes * 150 + np.random.randint(-20000, 20000, 100)  # Price in USD

# Create DataFrame
df = pd.DataFrame({
    'size_sqft': house_sizes,
    'price_usd': house_prices
})

print(df.head())
print(f"\nDataset shape: {df.shape}")
```

```python
# Cell 2: Train a simple model
# Prepare data
X = df[['size_sqft']]
y = df['price_usd']

# Split into training and test sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model
model = LinearRegression()
model.fit(X_train, y_train)

# Make predictions
y_pred = model.predict(X_test)

# Evaluate
r2 = r2_score(y_test, y_pred)
rmse = np.sqrt(mean_squared_error(y_test, y_pred))

print(f"Model trained! ✓")
print(f"R² Score: {r2:.3f}")
print(f"RMSE: ${rmse:,.2f}")
print(f"\nModel equation: Price = {model.coef_[0]:.2f} × Size + {model.intercept_:,.2f}")
```

```python
# Cell 3: Visualize results
plt.figure(figsize=(10, 6))

# Plot actual data
plt.scatter(X_test, y_test, color='blue', alpha=0.5, label='Actual prices')

# Plot predictions
plt.scatter(X_test, y_pred, color='red', alpha=0.5, label='Predicted prices')

# Plot regression line
plt.plot(X_test, y_pred, color='red', linewidth=2, label='Regression line')

plt.xlabel('House Size (sq ft)')
plt.ylabel('Price (USD)')
plt.title('House Price Prediction - Simple Linear Regression')
plt.legend()
plt.grid(True, alpha=0.3)

plt.tight_layout()
plt.show()

print("✓ Visualization complete!")
```

```python
# Cell 4: Save model to S3
import joblib
import io

# Save model locally first
joblib.dump(model, 'house_price_model.pkl')

# Upload to S3
with open('house_price_model.pkl', 'rb') as f:
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key='models/house_price_model.pkl',
        Body=f
    )

print("✓ Model saved to S3!")
print(f"Location: s3://{BUCKET_NAME}/models/house_price_model.pkl")
```

---

### Example 4: Load Pre-trained Model

```python
# Cell 1: Download and use saved model
import joblib
import io

# Download model from S3
obj = s3.get_object(Bucket=BUCKET_NAME, Key='models/house_price_model.pkl')
model_loaded = joblib.load(io.BytesIO(obj['Body'].read()))

# Make a prediction with the loaded model
new_house_size = [[2000]]  # 2000 sq ft house
predicted_price = model_loaded.predict(new_house_size)

print(f"✓ Model loaded from S3!")
print(f"\nPrediction for 2000 sq ft house:")
print(f"Estimated price: ${predicted_price[0]:,.2f}")
```

---

## Get Your Bucket Name

```bash
# Run this in your terminal to get the bucket name
terraform output data_bucket_name

# Copy the output and use it in your notebook code
```

---

## Useful SageMaker Commands

```bash
# Check notebook status
aws sagemaker describe-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart

# Stop the notebook (saves money when not using)
aws sagemaker stop-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart

# Start the notebook again
aws sagemaker start-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart

# List files in your S3 bucket
aws s3 ls s3://$(terraform output -raw data_bucket_name)/ --recursive
```

---

## Jupyter Shortcuts

Once in JupyterLab:

| Shortcut | Action |
|----------|--------|
| `Shift + Enter` | Run cell and move to next |
| `Ctrl + Enter` | Run cell (stay on current) |
| `A` | Insert cell above |
| `B` | Insert cell below |
| `D D` | Delete cell (press D twice) |
| `M` | Change cell to Markdown |
| `Y` | Change cell to Code |
| `Shift + M` | Merge cells |

---

## Stopping the Notebook (Important!)

When you're done working:

**Option 1: AWS Console**
1. Go to SageMaker → Notebook instances
2. Select your notebook
3. Click **Actions → Stop**

**Option 2: Command Line**
```bash
aws sagemaker stop-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart
```

**Why?** Notebook instances charge by the hour. Stop when not using to save costs.

---

## Completely Remove Everything

When you're completely done:

```bash
cd /home/anon/Documents/code/terraform

# Stop the notebook first
aws sagemaker stop-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart

# Wait for it to stop (2-3 minutes)
sleep 180

# Destroy all resources
terraform destroy
# Type 'yes' when prompted
```

---

## Troubleshooting

### "Notebook won't start"
```bash
# Check the status
aws sagemaker describe-notebook-instance \
  --notebook-instance-name ml-notebook-quickstart \
  --query 'FailureReason'

# Often just needs more time - wait 5 minutes
```

### "Can't access S3 bucket"
```python
# Make sure you copied the correct bucket name
import boto3
s3 = boto3.client('s3')
response = s3.list_buckets()
print("Available buckets:")
for bucket in response['Buckets']:
    if 'sagemaker' in bucket['Name']:
        print(f"  - {bucket['Name']}")
```

### "Package not found"
```bash
# SSH into notebook or use terminal in JupyterLab
# File → New → Terminal, then:
conda activate python3
pip install <package-name>
```

---

## Next Steps

1. ✓ Run the "Hello World" example to test
2. ✓ Try the S3 upload/download example
3. ✓ Run the ML example
4. Explore your own datasets
5. Try more complex models
6. Read SageMaker documentation: https://docs.aws.amazon.com/sagemaker/

**Pro tip:** Always save your notebooks to S3 before stopping the instance, or create a lifecycle config to auto-backup.
