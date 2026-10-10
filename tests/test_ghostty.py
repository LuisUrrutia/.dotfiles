"""The download adapter accepts only the cask's exact DMG, never a Nix app tree."""

import hashlib
import importlib.util
import lzma
from pathlib import Path
import struct
import unittest

SPEC = importlib.util.spec_from_file_location("ghostty_package", Path(__file__).resolve().parents[1] / "conf.d/ghostty/package.py")
ghostty = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ghostty)


def token(value):
    return struct.pack("<Q", len(value)) + value + bytes(-len(value) % 8)


def archive(content):
    packed = lzma.compress(content)
    info = {"Compression": "xz", "FileSize": str(len(packed)), "NarSize": str(len(content)),
            "FileHash": "sha256:" + ghostty.nix32(hashlib.sha256(packed).digest()),
            "NarHash": "sha256:" + ghostty.nix32(hashlib.sha256(content).digest())}
    return packed, info


class GhosttyDownloadTests(unittest.TestCase):
    def test_recovery_accepts_only_the_cask_dmg(self):
        dmg = b"The original DMG bytes"
        checksum = hashlib.sha256(dmg).hexdigest()
        content = b"".join(map(token, (b"nix-archive-1", b"(", b"type", b"regular", b"contents", dmg, b")")))
        packed, info = archive(content)

        recovered = ghostty.restore_dmg(packed, info, checksum)

        self.assertEqual(recovered, dmg)
        from compression import zstd
        compressed = zstd.compress(content)
        zstd_info = {**info, "Compression": "zstd", "FileSize": str(len(compressed)),
                    "FileHash": "sha256:" + ghostty.nix32(hashlib.sha256(compressed).digest())}
        self.assertEqual(ghostty.restore_dmg(compressed, zstd_info, checksum), dmg)
        # Independent cache evidence anchors Nix's fixed-output path encoding.
        self.assertEqual(ghostty.source_key("18cff2b0a6cee90eead9c7d3064e808a252a40baf214aa752c1ecb793b8f5f69"),
                            "lxpkzzmjcpscgwp2gb0bxgx43mn6i1xz")
        with self.assertRaisesRegex(RuntimeError, "cask checksum"):
            ghostty.restore_dmg(packed, info, "0" * 64)
        with self.assertRaisesRegex(RuntimeError, "cache checksum"):
            ghostty.restore_dmg(packed[:-1] + bytes([packed[-1] ^ 1]), info, checksum)
        with self.assertRaisesRegex(RuntimeError, "cache checksum"):
            ghostty.restore_dmg(packed, {**info, "NarHash": "sha256:" + "0" * 52}, checksum)
        for invalid in (content[:-1], content + token(b"extra"),
                        content.replace(token(b"regular"), token(b"directory")),
                        content.replace(token(b"regular"), token(b"symlink")),
                        content.replace(token(dmg), struct.pack("<Q", ghostty.MAX_SIZE + 1))):
            with self.subTest(archive=invalid), self.assertRaises(RuntimeError):
                ghostty.restore_dmg(*archive(invalid), checksum)


if __name__ == "__main__":
    unittest.main()
