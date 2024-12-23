#!/usr/bin/env python
# -*- coding: utf-8 -*-
from json import JSONDecodeError

import uvicorn
from loguru import logger
from fastapi import FastAPI, Request, Response

app = FastAPI(debug=True)


@app.middleware("http")
async def api_handler(request: Request, call_next):
    data = await request.form()
    if not data:
        try:
            data = await request.json()
        except JSONDecodeError:
            data = await request.body()
    request_info = f"{request.method} {request.url} data: {data}"
    logger.info(request_info)
    return Response(request_info)


if __name__ == '__main__':
    uvicorn.run(app, host='127.0.0.1', port=8421)
