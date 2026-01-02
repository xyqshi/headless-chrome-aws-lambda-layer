# Developer Guide - Headless Chrome AWS Lambda Layer

This guide covers how to build, test, and deploy the Headless Chrome Lambda Layer.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Building the Layer](#building-the-layer)
- [Local Testing](#local-testing)
- [Deploying to AWS](#deploying-to-aws)
- [Usage in Lambda](#usage-in-lambda)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

1. **Docker** - Required for building x86_64 binaries
   ```bash
   # Verify Docker is running
   docker info
   ```

2. **AWS SAM CLI** - For local Lambda testing
   ```bash
   # Install on macOS
   brew install aws-sam-cli
   
   # Verify installation
   sam --version
   ```

3. **Make** - Build automation
   ```bash
   make --version
   ```

4. **AWS CLI** (optional) - For deployment
   ```bash
   brew install awscli
   aws configure
   ```

---

## Project Structure

```
.
├── src/
│   ├── headless_chrome.py    # Main Chrome driver wrapper
│   └── lambda_function.py    # Sample Lambda handler
├── layer/
│   └── layer-headless_chrome-dev.zip  # Built layer (generated)
├── build/                    # Build artifacts (generated)
├── events/
│   └── test.json            # Test event for SAM
├── requirements/
│   └── layer.txt            # Python dependencies (selenium)
├── template.yaml            # SAM template
├── Makefile                 # Build commands
├── test-local.sh           # Local testing script
└── DEVELOPER.md            # This file
```

---

## Building the Layer

### Quick Build

```bash
make build
```

This will:
1. Install system libraries (X11, NSS, fonts, etc.) using Docker
2. Download ChromeDriver and Headless Chromium binaries
3. Download SwiftShader for GPU emulation
4. Install Python dependencies (Selenium)
5. Create `layer/layer-headless_chrome-dev.zip`

### Clean Build

```bash
make clean
make build
```

### Check Layer Size

```bash
# Layer should be under 250MB unzipped
ls -lh layer/layer-headless_chrome-dev.zip
du -sh build/headless_chrome/
```

---

## Local Testing

### Method 1: SAM CLI (Recommended)

Use the provided test script:

```bash
# Run the test
./test-local.sh

# Or use make
make test-sam
```

Or manually:

```bash
# Build SAM application
sam build --use-container

# Invoke function
sam local invoke TestFunction --event events/test.json
```

### Method 2: Direct Docker Test

Test without SAM:

```bash
# Extract layer
rm -rf /tmp/lambda_test && mkdir -p /tmp/lambda_test
unzip -q layer/layer-headless_chrome-dev.zip -d /tmp/lambda_test/opt
cp src/*.py /tmp/lambda_test/

# Run test
docker run --rm --platform linux/amd64 \
  -v "/tmp/lambda_test/opt:/opt" \
  -v "/tmp/lambda_test:/var/task" \
  -e "LD_LIBRARY_PATH=/opt/lib:/opt/swiftshader" \
  -e "FONTCONFIG_PATH=/opt/etc/fonts" \
  public.ecr.aws/lambda/python:3.12 \
  lambda_function.lambda_handler
```

### Method 3: Test Chrome Directly

Test Chrome without Selenium:

```bash
docker run --rm --platform linux/amd64 \
  -v "/tmp/lambda_test/opt:/opt" \
  -e "LD_LIBRARY_PATH=/opt/lib:/opt/swiftshader" \
  -e "FONTCONFIG_PATH=/opt/etc/fonts" \
  public.ecr.aws/amazonlinux/amazonlinux:2 \
  bash -c "/opt/headless-chromium --headless --no-sandbox --disable-gpu --dump-dom https://example.com"
```

### Custom Test Events

Create custom test events in `events/`:

```json
{
  "url": "https://example.com",
  "action": "screenshot"
}
```

Run with:

```bash
./test-local.sh events/custom.json
```

---

## Deploying to AWS

### Deploy with SAM

```bash
# First time - guided deployment
sam deploy --guided

# Subsequent deployments
sam deploy
```

### Deploy Layer Only

```bash
# Upload layer to S3
aws s3 cp layer/layer-headless_chrome-dev.zip s3://your-bucket/layers/

# Create layer version
aws lambda publish-layer-version \
  --layer-name headless-chrome \
  --compatible-runtimes python3.12 \
  --content S3Bucket=your-bucket,S3Key=layers/layer-headless_chrome-dev.zip
```

---

## Usage in Lambda

### Lambda Configuration

| Setting | Value |
|---------|-------|
| Runtime | Python 3.12 |
| Memory | 1024 MB (minimum) |
| Timeout | 60 seconds (adjust as needed) |
| Architecture | x86_64 |

### Environment Variables

| Variable | Value | Required |
|----------|-------|----------|
| `LD_LIBRARY_PATH` | `/opt/lib:/opt/swiftshader` | Recommended |
| `FONTCONFIG_PATH` | `/opt/etc/fonts` | Recommended |

> Note: These are set programmatically in `headless_chrome.py`, but setting them as Lambda environment variables is recommended for reliability.

### Sample Lambda Handler

```python
from headless_chrome import create_driver

def lambda_handler(event, context):
    driver = None
    try:
        driver = create_driver()
        driver.get("https://example.com")
        
        return {
            "statusCode": 200,
            "body": {
                "title": driver.title,
                "url": driver.current_url
            }
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": {"error": str(e)}
        }
    finally:
        if driver:
            driver.quit()
```

### Custom Chrome Arguments

```python
from headless_chrome import create_driver

# Add custom arguments
custom_args = [
    "--window-size=1920x1080",
    "--disable-javascript"
]
driver = create_driver(custom_config=custom_args)
```

---

## Troubleshooting

### Common Errors

#### "DevToolsActivePort file doesn't exist"

**Cause:** Chrome crashed during startup.

**Solution:** Ensure these flags are set:
- `--no-sandbox`
- `--disable-setuid-sandbox`
- `--single-process`
- `--no-zygote`
- `--remote-debugging-port=0`

#### "Chrome failed to start: exited abnormally"

**Cause:** Missing shared libraries or environment variables.

**Solution:**
1. Check `LD_LIBRARY_PATH` includes `/opt/lib:/opt/swiftshader`
2. Check `FONTCONFIG_PATH` is set to `/opt/etc/fonts`
3. Verify Lambda has at least 1024MB memory

#### "libsoftokn3.so: cannot open shared object file"

**Cause:** NSS libraries not included in layer.

**Solution:** Rebuild the layer - NSS libraries should be included automatically.

#### Layer exceeds 250MB limit

**Cause:** Too many dependencies or files.

**Solution:**
1. Check unzipped size: `du -sh build/headless_chrome/`
2. Remove unnecessary files from build
3. Consider using compression

### Debug Mode

Enable verbose Chrome logging:

```python
# In your Lambda handler
import logging
logging.basicConfig(level=logging.DEBUG)
```

### Check Binary Architecture

Verify binaries are x86_64:

```bash
file build/headless_chrome/chromedriver
file build/headless_chrome/headless-chromium
```

---

## Version Information

| Component | Version |
|-----------|---------|
| Python | 3.12 |
| Selenium | 4.25.0+ |
| ChromeDriver | 86.0.4240.22 |
| Headless Chromium | 86.0.4240.111 |

---

## Contributing

1. Make changes
2. Run `make build` to rebuild
3. Run `./test-local.sh` to test locally
4. Submit PR

---

## Links

- [Selenium Documentation](https://selenium-python.readthedocs.io/)
- [AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
