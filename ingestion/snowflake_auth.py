import os
import base64
import snowflake.connector
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization


def get_snowflake_connection(config):
    sf = config["snowflake"]
    auth = config.get("auth", {})

    private_key_b64 = os.getenv("SNOWFLAKE_PRIVATE_KEY_B64")

    if private_key_b64:
        pem_data = base64.b64decode(private_key_b64)
    else:
        key_path = os.path.expanduser(
            auth.get("private_key_path", "~/.ssh/snowflake_key.p8")
        )
        with open(key_path, "rb") as f:
            pem_data = f.read()

    pk = serialization.load_pem_private_key(
        pem_data, password=None, backend=default_backend()
    )
    pkb = pk.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )

    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        private_key=pkb,
        warehouse=sf["warehouse"],
        database=sf["database"],
        schema=sf["schema"],
    )
