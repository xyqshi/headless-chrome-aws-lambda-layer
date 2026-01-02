import sys
sys.path.insert(0, '/opt/python')

from headless_chrome import create_driver

def test_handler():
    print("Starting Chrome test...")
    try:
        driver = create_driver()
        print("Driver created successfully!")
        
        driver.get("https://www.google.com")
        print(f"Page title: {driver.title}")
        print(f"Current URL: {driver.current_url}")
        
        driver.quit()
        print("Test PASSED!")
        return {"status": "success", "title": driver.title}
    except Exception as e:
        print(f"Test FAILED: {e}")
        import traceback
        traceback.print_exc()
        return {"status": "error", "error": str(e)}

if __name__ == "__main__":
    test_handler()
