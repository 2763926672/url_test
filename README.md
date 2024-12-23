# URL 测试项目

主要用来测试 URL 的可用性，并记录测试结果。

## 初始化项目

1. 创建虚拟环境
```bash
python3 -m venv .venv
source .venv/bin/activate
```
2. 安装依赖
```bash
pip install -r requirements.txt
```
3. 启动项目
```bash
./manage.sh start
```

## manage.sh 说明

`manage.sh` 是一个用于管理项目服务的脚本工具。

### 命令行使用方式

```bash
./manage.sh [start|stop|restart]
```

### 参数说明

- `start`：启动项目
- `stop`：停止项目
- `restart`：重启项目

### 注意事项

- 项目启动时会自动检查代码更新，如果发现新的更新，会自动拉取更新。
- 项目启动时会自动检查代码更新，如果发现新的更新，会自动拉取更新。
- 项目启动时会自动检查代码更新，如果发现新的更新，会自动拉取更新。
