from pathlib import Path


def test_profile_contract_exists() -> None:
    assert Path(".template/profile.yaml").is_file()
