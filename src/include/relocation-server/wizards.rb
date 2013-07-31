# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:	clients/relocation-server.ycp
# Package:	Configuration of relocation-server
# Summary:	Main file
# Authors:	Li Dongyang <lidongyang@novell.com>
#
# $Id: relocation-server.ycp 27914 2006-02-13 14:32:08Z locilka $
#
# Main file for relocation-server configuration. Uses all other files.
module Yast
  module RelocationServerWizardsInclude
    def initialize_relocation_server_wizards(include_target)
      textdomain "relocation-server"

      Yast.import "Arch"
      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "CWMServiceStart"
      Yast.import "CWMFirewallInterfaces"

      Yast.include include_target, "relocation-server/complex.rb"
      Yast.include include_target, "relocation-server/dialogs.rb"
    end

    # Main workflow of the relocation-server configuration
    # @return sequence result
    def MainSequence
      widgets = {
        "fw-xend" => CWMFirewallInterfaces.CreateOpenFirewallWidget(
          {
            "services"        => ["service:xend-relocation-server"],
            "display_details" => true
          }
        ),
        "xend"    => {
          "widget"        => :custom,
          "help"          => Ops.get_string(@HELPS, "xend_configuration", ""),
          "custom_widget" => XendConfigurationDialogContent(),
          "handle"        => fun_ref(
            method(:HandleXendConfigurationDialog),
            "symbol (string, map)"
          ),
          "init"          => fun_ref(
            method(:InitXendConfigurationDialog),
            "void (string)"
          ),
          "store"         => fun_ref(
            method(:StoreXendConfigurationDialog),
            "void (string, map)"
          )
        },
        "kvm"     => {
          "widget"        => :custom,
          "help"          => Ops.get_string(@HELPS, "kvm_configuration", ""),
          "custom_widget" => KVMConfigurationDialogContent(),
          "handle"        => fun_ref(
            method(:HandleKVMConfigurationDialog),
            "symbol (string, map)"
          ),
          "init"          => fun_ref(
            method(:InitKVMConfigurationDialog),
            "void (string)"
          ),
          "store"         => fun_ref(
            method(:StoreKVMConfigurationDialog),
            "void (string, map)"
          )
        },
        "fw-kvm"  => CWMFirewallInterfaces.CreateOpenFirewallWidget(
          {
            "services"        => [
              "service:libvirtd-relocation-server",
              "service:sshd"
            ],
            "display_details" => true
          }
        )
      }

      tabs = {
        "xend_configuration" => {
          "header"       => _("&Xend"),
          "widget_names" => ["xend", "fw-xend"],
          "contents"     => XendConfigurationDialogContent()
        },
        "kvm_configuration"  => {
          "header"       => _("&KVM"),
          "widget_names" => ["kvm", "fw-kvm"],
          "contents"     => KVMConfigurationDialogContent()
        }
      }

      if !Arch.is_xen0
        Builtins.remove(tabs, "xend_configuration")
      else
        Builtins.remove(tabs, "kvm_configuration")
      end

      wd_arg = {
        "tab_order"    => ["xend_configuration"],
        "tabs"         => tabs,
        "widget_descr" => widgets,
        "initial_tab"  => "xend_configuration"
      }

      if !Arch.is_xen0
        Ops.set(wd_arg, "tab_order", ["kvm_configuration"])
        Ops.set(wd_arg, "initial_tab", "kvm_configuration")
      end

      wd = { "tab" => CWMTab.CreateWidget(wd_arg) }

      contents = VBox("tab")

      w = CWM.CreateWidgets(
        ["tab"],
        Convert.convert(
          wd,
          :from => "map <string, any>",
          :to   => "map <string, map <string, any>>"
        )
      )

      caption = _("Relocation Server Configuration")
      contents = CWM.PrepareDialog(contents, w)

      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.OKButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      Wizard.SetDesktopTitleAndIcon("relocation-server")

      CWM.Run(w, { :abort => fun_ref(method(:ReallyExit), "boolean ()") })
    end

    # Whole configuration of relocation-server
    # @return sequence result
    def RelocationServerSequence
      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("relocation-server")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      deep_copy(ret)
    end
  end
end
