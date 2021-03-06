/*******************************************************************************
 * Copyright (c) 2012 - 2018 Signal Iduna Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Contributors:
 * Signal Iduna Corporation - initial API and implementation
 * akquinet AG
 * itemis AG
 *******************************************************************************/
package org.testeditor.dsl.common.util

import org.eclipse.core.resources.IResourceChangeListener
import org.eclipse.core.resources.IWorkspace
import org.eclipse.core.resources.IWorkspaceRoot
import org.eclipse.core.resources.ResourcesPlugin

class WorkspaceHelper {
	
	def IWorkspaceRoot getRoot() {
		return workspace.root
	}
	
	def IWorkspace getWorkspace() {
		return ResourcesPlugin.workspace
	}
	
	def void addResourceChangeListener(IResourceChangeListener listener, int eventMask) {
		workspace.addResourceChangeListener(listener, eventMask)
	}
	
	def void removeResourceChangeListener(IResourceChangeListener listener){
		workspace.removeResourceChangeListener(listener)
	}

}
