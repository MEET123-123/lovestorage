from pathlib import Path
import importlib.util
import tempfile
import unittest

root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('deployment_config',root/'deploy/check-config.py')
config=importlib.util.module_from_spec(spec);spec.loader.exec_module(config)

class DeploymentConfigTest(unittest.TestCase):
    def test_placeholder_and_missing_files_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)
            self.assertTrue(config.validate(path))
            (path/'.env').write_text((root/'deploy/.env.example').read_text(encoding='utf-8'),encoding='utf-8')
            errors=config.validate(path)
            self.assertTrue(any('actual PostgreSQL' in e for e in errors))
            self.assertTrue(any('password' in e for e in errors))
    def test_existing_database_config_and_secret(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory);(path/'secrets').mkdir();(path/'certs').mkdir()
            (path/'.env').write_text('DB_URL=jdbc:postgresql://db.example.test:5432/smart_expiry?sslmode=verify-full&sslrootcert=/app/certs/root.crt\nDB_USERNAME=app\n',encoding='utf-8')
            (path/'secrets/db_password.txt').write_text('local-only-test-password',encoding='utf-8')
            (path/'certs/root.crt').write_text('placeholder-test-ca',encoding='utf-8')
            self.assertEqual(config.validate(path),[])
            (path/'.env').write_text('DB_URL=jdbc:postgresql://localhost:5432/smart_expiry?sslmode=disable\nDB_USERNAME=app\n',encoding='utf-8')
            self.assertTrue(any('localhost' in e for e in config.validate(path)))

if __name__=='__main__':unittest.main()
