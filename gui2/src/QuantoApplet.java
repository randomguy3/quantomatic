import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.StringTokenizer;
import javax.swing.JFileChooser;
import javax.swing.UIManager;
import processing.core.*;


public class QuantoApplet extends PApplet {

	private static final long serialVersionUID = 1L;
	public static final int WIDTH = 800;
	public static final int HEIGHT = 600;

	PFont helvetica;
	PFont times;

	Vertex selectedVertex = null;
	int selectedIndex = -1;
	char tool;
	JFileChooser fileChooser;
	Graph graph;
	boolean paused;
	boolean doSplines=true;
	int rectX=-1, rectY=-1;
	boolean shift=false;

	QuantoBack backend;
	XMLReader xml;
	static QuantoApplet p; // the top level applet 

	public void setup() {
		p = this;
		paused = false;
		size(WIDTH, HEIGHT, JAVA2D);
		smooth();
		frameRate(30);
		try {
			UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
		} catch (Exception e) {
			e.printStackTrace();
		}
		fileChooser = new JFileChooser();

		helvetica = loadFont("HelveticaNeue-14.vlw");
		times = loadFont("Times-Italic-14.vlw");

		graph = new Graph();
		tool = 's';

		// just some testing code here
		/*Vertex H = new Vertex("testH", 100, 100);
		H.setColor("H");
		graph.addVertex(H);

		Vertex bnd = new Vertex("boundary", 100, 200);
		bnd.setColor("boundary");
		graph.addVertex(bnd);

		Vertex red = new Vertex("testR", 200, 100);
		red.setColor("red");
		red.setAngle("\u03B1 + \u03B2");
		graph.addVertex(red);

		Vertex green = new Vertex("testG", 200, 200);
		green.setColor("green");
		green.setAngle("x");
		graph.addVertex(green);*/

		backend = new QuantoBack();
		xml = new XMLReader();
		
	}
	
	public void pause() {
		if (!paused) {
			noLoop();
			paused = true;
		} 
	}
	
	public void play() {
		if (paused) {
			loop();
			paused = false;
		}
	}
	
	public void mouseReleased() {
		if (tool=='s' && (mouseX!=rectX || mouseY!=rectY)) {
			for (Vertex v : graph.vertexList) {
				v.selected = v.inRect(rectX, rectY, mouseX, mouseY);
			}
		}
		rectX = -1;
		rectY = -1;
		play();
	}

	public void mousePressed() {
		Vertex n;
		switch (tool) {
		case 's':
			rectX = mouseX;
			rectY = mouseY;
			selectedVertex = null;
			// IMPROVE: use tree of locations for sub-object matching:
			// get log-time search for finding object from coordinates instead
			// of linear time.
			for (int i = 0; i < graph.vertexList.size(); ++i) {
				n = (Vertex) graph.vertexList.get(i);
				if (!shift) n.selected = false;
				if (n.at(mouseX, mouseY)) {
					n.selected = !n.selected;
				}
			}
			break;
		case 'm':
			float xAccum=0, yAccum=0;
			int vCount=0;
			for (Vertex v : graph.vertexList) {
				if (v.selected) {
					vCount++;
					xAccum += v.x;
					yAccum += v.y;
				}
			}
			if (vCount > 0) {
				xAccum /= (float)vCount;
				yAccum /= (float)vCount;
				for (Vertex v : graph.vertexList) {
					if (v.selected) {
						v.clearEdgeControlPoints();
						v.setDest((int)(v.x+mouseX-xAccum), (int)(v.y+mouseY-yAccum));
					}
				}
			}
			break;
		case 'e':
			for (Vertex v : graph.vertexList) {
				if (v.at(mouseX, mouseY)) {
					for (Vertex w : graph.vertexList) {
						if (w.selected)
							modifyGraph("e " + w.id + " " + v.id + "\n");
					}
				}
			}
			break;
		}
		
		play();
	}

	public void keyPressed() {
		if (key == tool) {
			tool = 's';
			play();
			return;
		}
		
		switch (key) {
		case 'l':
			layout(graph);
			break;
		case 'r':
		case 'g':
		case 'h':
		case 'b': /* add new nodes */
			modifyGraph(key + "");
			if (graph.newestVertex!=null) {
				Vertex w = graph.newestVertex;
				for (Vertex v : graph.vertexList) {
					if (v.selected) modifyGraph("e " + v.id + " " + w.id + "\n");
				}
			}
			break;
		case 'n':
		case 'u': /* other back-end commands, just pass them on */
			modifyGraph(key + "");
			break;
		case 'd':
			for (Vertex v : graph.vertexList) {
				if (v.selected) modifyGraph("d " + selectedVertex.id);
			}
			break;
		case 'q':
			println("Shutting down quantoML");
			backend.send("Q\n");
			println(backend.receive());
			backend.send("quit () ; \n");
			println("Quitting....");
			exit();
			break;
		case 'p':
			doSplines = !doSplines;
			break;
		case CODED:
			if (keyCode == SHIFT) shift = true;
			break;
		case 's':
		case 'm':
		case 'e': /* these are tools that require mouse input too */
			tool = key;
			break;
		}
		
		play();
	}
	
	public void keyReleased() {
		shift = false;
	}

	void modifyGraph(String cmd) {
		backend.send(cmd + "\n");
		println(backend.receive());
		// here send D to backend and dump the graph
		// then rebuild it via the XML parser.
		backend.send("D\n");
		Graph updated = xml.parseGraph(backend.receive());
		updated.reconcileVertices(graph);
		this.graph = updated;
		graph.layoutGraph();
		
		play();
	}

	public void draw() {
		background(255);
		textFont(helvetica);
		fill(255, 0, 0);
		switch (tool) {
		case 's':
			text("SELECT", 10, 20);
			break;
		case 'm':
			text("MOVE", 10, 20);
			break;
		case 'e':
			text("EDGE", 10, 20);
			break;
		}

		
		boolean moved = false;
		for (Vertex v : graph.vertexList) {
			moved = moved || v.tick();
			v.tick();
			v.display();
		}
		
		if (moved) {
			for (Edge e : graph.edgeList) e.display(true);
		} else {
			for (Edge e : graph.edgeList) e.display(false);
		}
		
		if (rectX!=-1) {
			moved = true;
			fill(100,100,255,30);
			stroke(100,100,255);
			rect(rectX, rectY, mouseX-rectX, mouseY-rectY);
		}
		
		if (!moved) pause();
	}


	String makeDot(Graph graph) {
		StringBuffer g = new StringBuffer();
		g.append("digraph {\n");
		

		
		for (Vertex v : graph.vertexList) {
			g.append("{rank=same; ");
			g.append(v.id);
			g.append(" [color=\"");
			g.append(v.col);
			g.append("\"];}\n");
		}

		for (Edge e : graph.edgeList) {
			g.append(e.source.id);
			g.append("->");
			g.append(e.dest.id);
			//g.append(" [arrowhead=none,headclip=false,tailclip=false];\n");
			g.append(" [arrowhead=none];\n");
		}

		g.append("\n}\n");
		return g.toString();
	}

	void layout(Graph graph) {
		layout(makeDot(graph), graph);
	}

	void layout(String viz, Graph graph) {
		try {
			Process dot = Runtime.getRuntime().exec("dot -Tplain");
			BufferedReader dotIn = new BufferedReader(new InputStreamReader(dot
					.getInputStream()));

			OutputStreamWriter dotOut = new OutputStreamWriter(dot
					.getOutputStream());

			dotOut.write(viz);
			dotOut.close();

			println("NOW READING DOT");
			String ln = dotIn.readLine();
			StringTokenizer tk;
			String cmd, name;
			int x, y;
			Vertex n, n1, n2;
			graph.edges.clear();
			graph.edgeList.clear();
			while (!ln.equals("stop")) {
				println(ln);
				tk = new StringTokenizer(ln);
				cmd = tk.nextToken();
				if (cmd.equals("node")) {
					name = tk.nextToken();
					n = (Vertex) graph.vertices.get(name);
					if (n == null) {
						n = new Vertex(name, 50, 50);
						graph.addVertex(n);
					}
					x = (int) (Float.parseFloat(tk.nextToken()) * 50.0) + 20;
					y = (int) (Float.parseFloat(tk.nextToken()) * 50.0) + 20;

					tk.nextToken();
					tk.nextToken();
					tk.nextToken();
					tk.nextToken();
					tk.nextToken();
					n.setColor(tk.nextToken());
					n.setDest(x, y);
				} else if (cmd.equals("edge")) {
					n1 = (Vertex) graph.vertices.get(tk.nextToken());
					n2 = (Vertex) graph.vertices.get(tk.nextToken());
					
					if (n1 == null || n2 == null) {
						println("Edge spec given before vertices defined.");
					} else {
						Edge e = graph.newEdge(n1, n2);
						int controlCount = Integer.parseInt(tk.nextToken());
						
						for (int i=0;i<controlCount;++i) {
							x = (int) (Float.parseFloat(tk.nextToken()) * 50.0) + 20;
							y = (int) (Float.parseFloat(tk.nextToken()) * 50.0) + 20;
							e.addControlPoint(x,y);
						}
					}
				}
				ln = dotIn.readLine();
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
		println("----NO MORE READING DOT----");
	}

}
