import os
import sys
import tarfile
import time
from huggingface_hub import HfApi, hf_hub_download

api = HfApi()
repo_id = os.getenv("HF_DATASET")
token = os.getenv("HF_TOKEN")
FILENAME = "latest_backup.tar.gz"
BACKUP_PATH = "/root/.openclaw"

def restore():
    """启动时恢复数据"""
    if not repo_id or not token:
        print("⚠️ Skip Restore: HF_DATASET or HF_TOKEN not set")
        return False
    
    try:
        print(f"⬇️ Downloading {FILENAME} from {repo_id}...")
        # 下载最新备份
        path = hf_hub_download(repo_id=repo_id, filename=FILENAME, repo_type="dataset", token=token)
        
        if os.path.exists(path):
            with tarfile.open(path, "r:gz") as tar:
                tar.extractall(path=BACKUP_PATH)
            print(f"✅ Success: Restored from {FILENAME}")
            return True
    except Exception as e:
        print(f"ℹ️ Restore Note: No existing backup found or error: {e}")
    return False

def backup():
    """定时备份数据"""
    if not repo_id or not token:
        return

    try:
        temp_tar = "/tmp/latest_backup.tar.gz"
        paths_to_backup = [
            "sessions",
            "workspace",
            "credentials",
            "openclaw.json",
            "agents/main/sessions",
            "agents/main/SOUL.md",
            "agents/main/USER.md",
            "agents/main/IDENTITY.md"
        ]
        
        with tarfile.open(temp_tar, "w:gz") as tar:
            for p in paths_to_backup:
                full_path = os.path.join(BACKUP_PATH, p)
                if os.path.exists(full_path):
                    arcname = p
                    tar.add(full_path, arcname=arcname)
        
        # 上传覆盖
        api.upload_file(
            path_or_fileobj=temp_tar,
            path_in_repo=FILENAME,
            repo_id=repo_id,
            repo_type="dataset",
            token=token
        )
        print(f"💾 Backup {FILENAME} Success at {time.strftime('%X')}")
        
        # 清理临时文件
        if os.path.exists(temp_tar):
            os.remove(temp_tar)
            
    except Exception as e:
        print(f"❌ Backup Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "backup":
        backup()
    else:
        restore()
