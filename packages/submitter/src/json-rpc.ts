// import { base64 } from "ethers/lib/utils";

interface JsonRpcOpts {
  url: string;
  username?: string;
  password?: string;
  // headers: { [key: string]: string };
}

interface JsonRpcReq {
  jsonrpc: "2.0";
  id: number;
  method: string;
  params: any[] | Record<string, any>;
}

interface JsonRpcRes {
  jsonrpc: "2.0";
  id: number | string;
  result?: any;
  error?: { code: number; message: string; data?: any };
}

export class JsonRpcClient {
  nextID = 1;
  options: JsonRpcOpts;
  constructor(options: JsonRpcOpts) {
    this.options = options;
  }

  async req(
    method: string,
    params: any[] | Record<string, any>
  ): Promise<JsonRpcRes> {
    const { url, username, password } = this.options;
    const req: JsonRpcReq = {
      id: this.nextID++,
      jsonrpc: "2.0",
      method,
      params,
    };

    const headers = {
      "Content-Type": "application/json"
    } as Record<string, string>;

    if (username && password) {
      headers["Authorization"] = 'Basic ' + Buffer.from(`${username}:${password}`).toString('base64');
    }

    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(req),
    });

    let ret = null as JsonRpcRes | null;
    try {
      ret = (await res.json()) as JsonRpcRes;
      if (ret.id !== req.id) throw new Error("id mismatch");
      return ret;
    } catch (e) {
      throw new Error(
        `JSONRPC method ${method} error ${e}, ` +
        `${url} sent ${res.status} ${res.statusText}, ` +
        `request ${JSON.stringify(req)}, response ${JSON.stringify(ret)}`
      );
    }
  }
}
