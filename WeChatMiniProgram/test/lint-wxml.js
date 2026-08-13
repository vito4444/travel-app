// 渲染层静态校验：node WeChatMiniProgram/test/lint-wxml.js
// 1. WXML 标签闭合配对；2. 事件绑定的处理函数在对应页面 JS 中存在；
// 3. wx:for 必须配 wx:key；4. {{ }} 表达式配对；5. WXSS 花括号配对。
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
let problems = 0;

function report(file, message) {
  problems += 1;
  console.log('LINT-FAIL ' + path.relative(ROOT, file) + ' : ' + message);
}

/** 去注释后按引号感知切分出所有标签。 */
function tokenizeTags(source) {
  const text = source.replace(/<!--[\s\S]*?-->/g, '');
  const tags = [];
  let i = 0;
  while (i < text.length) {
    if (text[i] !== '<') {
      i += 1;
      continue;
    }
    let j = i + 1;
    let quote = null;
    while (j < text.length) {
      const ch = text[j];
      if (quote) {
        if (ch === quote) quote = null;
      } else if (ch === '"' || ch === "'") {
        quote = ch;
      } else if (ch === '>') {
        break;
      }
      j += 1;
    }
    tags.push(text.slice(i, j + 1));
    i = j + 1;
  }
  return tags;
}

function lintWxml(file, pageMethods) {
  const source = fs.readFileSync(file, 'utf8');

  // {{ }} 配对
  const openCount = (source.match(/\{\{/g) || []).length;
  const closeCount = (source.match(/\}\}/g) || []).length;
  if (openCount !== closeCount) {
    report(file, '模板表达式 {{ 与 }} 数量不一致：' + openCount + ' vs ' + closeCount);
  }

  const stack = [];
  const tags = tokenizeTags(source);
  tags.forEach((tag) => {
    const closing = /^<\/\s*([\w-]+)/.exec(tag);
    if (closing) {
      const expected = stack.pop();
      if (expected !== closing[1]) {
        report(file, '标签闭合不匹配：期望 </' + expected + '> 实得 </' + closing[1] + '>');
      }
      return;
    }
    const opening = /^<\s*([\w-]+)/.exec(tag);
    if (!opening) return;
    const name = opening[1];
    const selfClosed = /\/>$/.test(tag);

    // wx:for 必须带 wx:key
    if (tag.indexOf('wx:for') >= 0 && tag.indexOf('wx:key') < 0) {
      report(file, '<' + name + '> 用了 wx:for 但缺 wx:key');
    }

    // 事件绑定的方法必须存在
    const eventRe = /(?:bind|catch)[:]?([a-z]+)="([^"]+)"/g;
    let match;
    while ((match = eventRe.exec(tag)) !== null) {
      const handler = match[2];
      if (handler.indexOf('{{') >= 0) continue;
      if (!pageMethods.has(handler)) {
        report(file, '<' + name + '> 绑定的处理函数 ' + handler + ' 在页面 JS 中不存在');
      }
    }

    if (!selfClosed) stack.push(name);
  });
  if (stack.length) {
    report(file, '存在未闭合标签：' + stack.join(', '));
  }
}

/** 从页面 JS 提取 Page({}) 的方法名。 */
function extractMethods(jsFile) {
  const methods = new Set();
  if (!fs.existsSync(jsFile)) return methods;
  const source = fs.readFileSync(jsFile, 'utf8');
  const methodRe = /^\s{2}(?:async\s+)?([A-Za-z_$][\w$]*)\s*\(/gm;
  let match;
  while ((match = methodRe.exec(source)) !== null) {
    methods.add(match[1]);
  }
  const propFnRe = /^\s{2}([A-Za-z_$][\w$]*)\s*:\s*(?:async\s*)?function/gm;
  while ((match = propFnRe.exec(source)) !== null) {
    methods.add(match[1]);
  }
  return methods;
}

function lintWxss(file) {
  const source = fs.readFileSync(file, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
  let depth = 0;
  for (const ch of source) {
    if (ch === '{') depth += 1;
    if (ch === '}') depth -= 1;
    if (depth < 0) break;
  }
  if (depth !== 0) {
    report(file, 'WXSS 花括号不配对（差 ' + depth + '）');
  }
}

const pagesDir = path.join(ROOT, 'pages');
const pages = fs.readdirSync(pagesDir);
let wxmlCount = 0;
let wxssCount = 0;

pages.forEach((page) => {
  const dir = path.join(pagesDir, page);
  const wxml = path.join(dir, page + '.wxml');
  const js = path.join(dir, page + '.js');
  const wxss = path.join(dir, page + '.wxss');
  if (fs.existsSync(wxml)) {
    wxmlCount += 1;
    lintWxml(wxml, extractMethods(js));
  }
  if (fs.existsSync(wxss)) {
    wxssCount += 1;
    lintWxss(wxss);
  }
});
lintWxss(path.join(ROOT, 'app.wxss'));
wxssCount += 1;

console.log('检查了 ' + wxmlCount + ' 个 WXML、' + wxssCount + ' 个 WXSS');
console.log(problems === 0 ? 'LINT ALL PASSED' : problems + ' LINT FAILURES');
process.exit(problems === 0 ? 0 : 1);
