from td0015_hosted_consumer import profile_label


def test_profile_label_is_starter() -> None:
    assert profile_label() == "starter"
