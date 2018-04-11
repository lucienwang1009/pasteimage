import sublime
import sublime_plugin
import os,subprocess
from functools import partial

class ImagePasteCommand(sublime_plugin.TextCommand):
    def run(self, edit):
        return_code = os.system('pngpaste -a')
        if return_code != 0:
            self.view.run_command('paste')
        else:
            self.view.window().show_input_panel('Image Name:', '', self.on_done, None, None)

    def on_done(self, input_string):
        view = self.view
        # create dir in current path with the name of current filename
        dirname, _ = os.path.split(view.file_name())
        figs_dir = 'figs'
        fn = None
        abs_figs_dir = os.path.join('%s/%s' % (dirname, figs_dir))
        abs_fn = ''
        rel_fn = ''

        # create new image file under currentdir/filename_without_ext/filename_without_ext%d.png
        if not os.path.lexists(abs_figs_dir):
            os.mkdir(abs_figs_dir)
        fn = input_string
        rel_fn = os.path.join("%s/%s.png" % (figs_dir, fn))
        abs_fn = os.path.join(abs_figs_dir, "%s.png" % fn)

        content = sublime.get_clipboard()
        if os.path.exists(content):
            os.system('cp -r "%s" %s' % (content, abs_fn))
        else:
            return_code = os.system('pngpaste %s' % abs_fn)
        for pos in view.sel():
            if 'text.html.markdown' in view.scope_name(pos.begin()):
                self.view.run_command("insert", {"characters": "![](%s)" % rel_fn})
            else:
                self.view.run_command("insert", {"characters": "%s" % rel_fn})
            # only the first cursor add the path
            break
