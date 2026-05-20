import yaml
import sys

def validate_config(path):
    if not os.path.exists(path):
        print(f"File {path} not found.")
        return False
    with open(path, 'r') as f:
        try:
            config = yaml.safe_load(f)
            if 'model_list' not in config:
                print("Error: 'model_list' missing in LiteLLM config.")
                return False
            print(f"Validation successful for {path}")
            return True
        except Exception as e:
            print(f"Error parsing YAML: {e}")
            return False

if __name__ == "__main__":
    import os
    if not validate_config('terraform/k8s/litellm-config.yaml'):
        sys.exit(1)
