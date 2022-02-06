# Trim and Keep (C) Copyright 2022 jim.foltz@gmail.com
# Version: 0.1
#
# License: MIT

=begin

MIT License

Copyright (c) 2022 jim.foltz@gmail.com

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice (including the
next paragraph) shall be included in all copies or substantial portions
of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=end

# Trim and Keep aims to "fix" SketchUp Pro's Solid Tools Trim function. As it currently
# works, SketchUp's trim changes ComponentInstances into Groups.
#
require 'sketchup'

module JF; class TrimAndKeep
    def activate
        unless Sketchup.is_pro?
            UI.messagebox("Trim and Keep requires SketchUp Pro.")
            return
        end
        @model = Sketchup.active_model
        @sel   = @model.selection
        reset
    end

    def reset
        @state        = 0
        @first_picked = nil
        @last_thing   = nil
        @sel.clear
        do_status_text
    end

    def onMouseMove(flags, x, y, view)
        ph = view.pick_helper
        st = ph.do_pick(x, y)
        thing = ph.best_picked
        if @last_thing != thing
            @sel.clear
            @sel.add(thing) if thing.class.to_s[/Sketchup::(Group|ComponentInstance)/] and thing.manifold?
        end
        @last_thing = thing
    end

    def onLButtonDown(flags, x, y, view)
        ph = view.pick_helper
        st = ph.do_pick(x, y)
        thing = ph.best_picked
        if @state == 0
            # Pick first entitiy - the disposable subtractor.
            if thing.class == Sketchup::Group or thing.class == Sketchup::ComponentInstance
                unless thing.manifold?
                    UI.messagebox("Selection not manifold.")
                    return
                end
                @first_picked = thing
                @sel.add(thing)
                @state = 1
            end
        elsif @state == 1
            # Pick the subtractee - the thing we want to keep.
            if thing.class == Sketchup::Group or thing.class == Sketchup::ComponentInstance
                unless thing.manifold?
                    UI.messagebox("Selection not manifold.")
                    return
                end
                @last_picked = thing
                do_subtract()
            end
        end
        do_status_text
    end

    def resume(view)
        do_status_text
    end

    def do_subtract
        @model.start_operation("Trim and Keep", true)
        def_to_keep = @last_picked.definition
        if @last_picked.class == Sketchup::Group
            name = @last_picked.name
        else
            name = @last_picked.definition.name
        end
        # Rename in order to make the original name available for the new Def created by .trim
        def_to_keep.name = @model.definitions.unique_name(name)
        grp = @first_picked.trim(@last_picked)
        if @last_picked.class == Sketchup::ComponentInstance
            new_instance = grp.to_component
            new_def = new_instance.definition
            Sketchup.status_text = "Replacing instances..."
            def_to_keep.instances.each {|i| i.definition = new_def}
            new_def.name = name
        else
            grp.name = name
        end
        @model.commit_operation
        reset
    end

    def do_status_text
        case @state
        when 0
            Sketchup.set_status_text("Select the \"cutter\" Group or Instance.")
        when 1
            Sketchup.set_status_text("Select the \"keeper\" Instance.")
        end
    end

end # class TrimAndKeep

end # module JF

unless file_loaded?(File.basename(__FILE__))
    UI.menu("Tools").add_item("Trim && Keep") { Sketchup.active_model.select_tool(JF::TrimAndKeep.new) }
    file_loaded(File.basename(__FILE__))
end

