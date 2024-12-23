#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 设置项目根目录路径（根据实际情况修改）
PROJECT_DIR="$HOME/Work/url_test"  # 替换为你的项目实际路径
APP="main:app"
PORT=8000
HOST="0.0.0.0"
WORKERS=9
LOG_CONFIG=""  # uvicorn 日志配置文件路径
VENV_PATH=".venv/bin/activate"
GIT_BRANCH="main"  # 设置要跟踪的分支名称

# Git更新检查函数
check_git_update() {
    printf "${BLUE}检查代码更新...${NC}\n"
    
    # 检查是否是git仓库
    if [ ! -d ".git" ]; then
        printf "${YELLOW}警告：当前目录不是git仓库，跳过更新检查${NC}\n"
        return 0
    fi

    # 保存当前分支名
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$GIT_BRANCH" ]; then
        printf "${YELLOW}警告：当前分支(%s)与目标分支(%s)不符，跳过更新检查${NC}\n" "$current_branch" "$GIT_BRANCH"
        return 0
    fi

    # 获取远程更新信息
    if ! git fetch origin $GIT_BRANCH 2>/dev/null; then
        printf "${RED}错误：无法连接到远程仓库${NC}\n"
        return 1
    fi

    # 检查是否有更新
    local updates=$(git rev-list HEAD...origin/$GIT_BRANCH --count)
    if [ "$updates" -eq 0 ]; then
        printf "${GREEN}代码已是最新版本${NC}\n"
        return 0
    fi

    printf "${BLUE}发现新的更新${NC}\n"
    printf "${BLUE}更新内容：${NC}\n"
    # 显示更新日志
    git log --oneline HEAD..origin/$GIT_BRANCH

    # 询问用户是否更新,默认为否
    read -p "是否要更新代码? (y/N) " answer
    if [[ $answer != "y" && $answer != "Y" ]]; then
        printf "${YELLOW}已取消更新${NC}\n"
        return 0
    fi

    printf "${BLUE}正在拉取更新...${NC}\n"
    # 保存当前的commit hash以便回滚
    local current_commit=$(git rev-parse HEAD)

    # 尝试拉取更新
    if ! git pull origin $GIT_BRANCH --ff-only >/dev/null 2>&1; then
        printf "${RED}更新失败：可能存在冲突${NC}\n"
        # 回滚到之前的状态
        git reset --hard $current_commit >/dev/null 2>&1
        printf "${YELLOW}已回滚到更新前的状态${NC}\n"
        return 1
    fi

    printf "${GREEN}代码更新成功${NC}\n"
    # 显示更新日志
    printf "${BLUE}更新内容：${NC}\n"
    git log --oneline "$current_commit..HEAD"
    return 0
}

# 启动服务函数
start_service() {
    printf "${BLUE}准备启动服务...${NC}\n"
    
    # 检查项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        printf "${RED}错误：项目目录不存在：%s${NC}\n" "$PROJECT_DIR"
        return 1
    fi

    # 切换到项目目录
    printf "${BLUE}切换到项目目录：%s${NC}\n" "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    # 检查并更新代码
    if ! check_git_update; then
        printf "${RED}代码更新失败，终止启动服务${NC}\n"
        return 1
    fi

    # 检查虚拟环境
    if [ ! -f "$VENV_PATH" ]; then
        printf "${RED}错误：找不到虚拟环境：%s/%s${NC}\n" "$PROJECT_DIR" "$VENV_PATH"
        return 1
    fi

    # 激活虚拟环境
    printf "${BLUE}正在激活虚拟环境...${NC}\n"
    source $VENV_PATH

    # 检查是否成功激活虚拟环境
    if [ -z "$VIRTUAL_ENV" ]; then
        printf "${RED}错误：虚拟环境激活失败${NC}\n"
        return 1
    fi
    printf "${GREEN}虚拟环境已激活：%s${NC}\n" "$VIRTUAL_ENV"

    # 检查日志配置文件
    if [ -n "$LOG_CONFIG" ] && [ ! -f "$LOG_CONFIG" ]; then
        printf "${RED}错误：找不到日志配置文件：%s/%s${NC}\n" "$PROJECT_DIR" "$LOG_CONFIG"
        deactivate
        return 1
    fi

    # 检查端口是否已被占用
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
        printf "${RED}错误：端口 %d 已被占用${NC}\n" "$PORT"
        deactivate
        return 1
    fi

    # 构建 uvicorn 启动命令
    UVICORN_CMD="nohup uvicorn $APP --workers $WORKERS --host $HOST --port $PORT"
    if [ -n "$LOG_CONFIG" ]; then
        UVICORN_CMD="$UVICORN_CMD --log-config $LOG_CONFIG"
    fi

    # 启动服务
    printf "${BLUE}正在启动 uvicorn 服务...${NC}\n"
    $UVICORN_CMD >/dev/null 2>&1 &
    
    # 等待2秒让服务启动
    sleep 2
    
    # 获取端口上的进程ID
    PIDS=$(lsof -i:$PORT -t)
    
    # 检查服务是否成功启动
    if [ -n "$PIDS" ] && ps -p $PIDS >/dev/null 2>&1; then
        printf "${GREEN}服务启动成功！${NC}\n"
        printf "${GREEN}进程:${NC}\n"
        ps -p $PIDS
        printf "${GREEN}API文档: http://%s:%d/docs${NC}\n" "$HOST" "$PORT"
    else
        printf "${RED}服务启动失败！${NC}\n"
        deactivate
        return 1
    fi

    # 退出虚拟环境
    deactivate
    printf "${GREEN}虚拟环境已退出${NC}\n"
    return 0
}

# 停止服务函数
stop_service() {
    printf "${BLUE}开始停止 uvicorn 服务...${NC}\n"
    
    PIDS=$(lsof -i:$PORT -t)

    if [ -z "$PIDS" ]; then
        printf "${YELLOW}没有找到运行中的 uvicorn 进程${NC}\n"
        return 0
    fi

    # 显示找到的进程
    printf "${BLUE}找到以下 uvicorn 进程：${NC}\n"

    ps -p $PIDS

    # 终止所有找到的进程
    printf "${BLUE}正在停止进程...${NC}\n"
    for PID in $PIDS
    do
        kill -9 $PID 2>/dev/null || true
        printf "${GREEN}已终止进程 %s${NC}\n" "$PID"
    done

    printf "${GREEN}所有 uvicorn 进程已停止${NC}\n"
    return 0
}

# 重启服务函数
restart_service() {
    printf "${BLUE}正在重启服务...${NC}\n"
    stop_service
    sleep 2
    start_service
}

# 显示菜单
show_menu() {
    printf "${BLUE}==========================${NC}\n"
    printf "${YELLOW}      项目管理脚本${NC}\n"
    printf "${BLUE}==========================${NC}\n"
    printf "${GREEN}1. 启动服务${NC}\n"
    printf "${RED}2. 停止服务${NC}\n"
    printf "${YELLOW}3. 重启服务${NC}\n"
    printf "${BLUE}0. 退出${NC}\n"
    printf "${BLUE}==========================${NC}\n"
}

# 主程序
main() {
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "请选择操作 [0-3]: " choice
            case $choice in
                1)
                    start_service
                    ;;
                2)
                    stop_service
                    ;;
                3)
                    restart_service
                    ;;
                0)
                    echo "退出程序"
                    exit 0
                    ;;
                *)
                    printf "${RED}无效的选择，请重试${NC}\n"
                    ;;
            esac
            printf "${BLUE}按回车键继续...${NC}\n"
            read
        done
    else
        case $1 in
            1|start)
                start_service
                ;;
            2|stop)
                stop_service
                ;;
            3|restart)
                restart_service
                ;;
            *)
                printf "${RED}用法: %s [start|stop|restart]${NC}\n" "$0"
                exit 1
                ;;
        esac
    fi
}

# 运行主程序
main "$@" 