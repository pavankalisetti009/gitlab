import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';

export default Extension.create({
  name: 'selection',

  addProseMirrorPlugins() {
    let contextMenuVisible = false;
    let lastClickTime = 0;

    const findWordBoundary = (doc, pos, direction) => {
      const WORD_CHAR_REGEX = /[\p{L}\p{N}]/u;
      let currentPos = pos;
      
      while (currentPos > 0 && currentPos < doc.nodeSize - 2) {
        const char = doc.textBetween(currentPos + (direction > 0 ? 0 : -1), currentPos + (direction > 0 ? 1 : 0));
        if (!WORD_CHAR_REGEX.test(char)) break;
        currentPos += direction;
      }
      return currentPos;
    };

    return [
      new Plugin({
        key: new PluginKey('selection'),
        props: {
          handleDOMEvents: {
            contextmenu() {
              contextMenuVisible = true;
              setTimeout(() => {
                contextMenuVisible = false;
              });
            },
            mousedown(view, event) {
              const currentTime = Date.now();
              if (currentTime - lastClickTime < 400) {
                event.preventDefault();

                const pos = view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos;
                if (!pos) return;

                const startPos = findWordBoundary(view.state.doc, pos, -1);
                const endPos = findWordBoundary(view.state.doc, pos, 1);

                const { state, dispatch } = view;
                let tr = state.tr.setSelection(
                  state.tr.selection.constructor.between(
                    state.doc.resolve(startPos),
                    state.doc.resolve(endPos)
                  )
                );
                dispatch(tr);

                const handleMouseMove = (e) => {
                  const currentPos = view.posAtCoords({ left: e.clientX, top: e.clientY })?.pos;
                  if (!currentPos) return;

                  const newEndPos = findWordBoundary(view.state.doc, currentPos, currentPos > pos ? 1 : -1);
                  tr = view.state.tr.setSelection(
                    view.state.tr.selection.constructor.between(
                      view.state.doc.resolve(startPos),
                      view.state.doc.resolve(newEndPos)
                    )
                  );
                  view.dispatch(tr);
                };

                const handleMouseUp = () => {
                  document.removeEventListener('mousemove', handleMouseMove);
                  document.removeEventListener('mouseup', handleMouseUp);
                };

                document.addEventListener('mousemove', handleMouseMove);
                document.addEventListener('mouseup', handleMouseUp);
                
              }
              lastClickTime = currentTime;
            }
          },
          decorations(state) {
            if (state.selection.empty || contextMenuVisible) return null;

            return DecorationSet.create(state.doc, [
              Decoration.inline(state.selection.from, state.selection.to, {
                class: 'content-editor-selection',
              }),
            ]);
          },
        },
      }),
    ];
  },
});